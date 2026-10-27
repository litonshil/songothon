package middleware

import (
	"context"
	"strings"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"

	"songothon/internal/domain"
	"songothon/pkg/response"
	"songothon/pkg/token"
)

const (
	ContextKeyUserID        = "user_id"
	ContextKeyUserEmail     = "user_email"
	ContextKeyCurrentOrg    = "current_org"
	ContextKeyCurrentMember = "current_member"
	ContextKeyMemberRole    = "current_member_role"
)

type OrgLookupRepository interface {
	GetBySlug(ctx context.Context, slug string) (*domain.Organization, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error)
	GetMember(ctx context.Context, orgID, userID uuid.UUID) (*domain.OrganizationMember, error)
}

func AuthMiddleware(tm *token.TokenManager) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return response.Unauthorized(c, "Authorization token is required")
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if !(len(parts) == 2 && strings.EqualFold(parts[0], "Bearer")) {
				return response.Unauthorized(c, "Invalid authorization header format. Expected 'Bearer <token>'")
			}

			claims, err := tm.ValidateToken(parts[1])
			if err != nil {
				return response.Unauthorized(c, "Invalid or expired authorization token")
			}

			c.Set(ContextKeyUserID, claims.UserID)
			c.Set(ContextKeyUserEmail, claims.Email)
			return next(c)
		}
	}
}

func TenantMiddleware(orgRepo OrgLookupRepository) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			userIDVal := c.Get(ContextKeyUserID)
			userID, ok := userIDVal.(uuid.UUID)
			if !ok {
				return response.Unauthorized(c, "Unauthenticated user context")
			}

			// Extract org slug or ID from Header, Route Param, or Query
			orgSlug := c.Request().Header.Get("X-Org-Slug")
			if orgSlug == "" {
				orgSlug = c.Param("slug")
			}
			if orgSlug == "" {
				orgSlug = c.QueryParam("org_slug")
			}

			var org *domain.Organization
			var err error

			if orgSlug != "" {
				org, err = orgRepo.GetBySlug(c.Request().Context(), orgSlug)
			} else {
				// Fallback to org_id in route param or header
				orgIDStr := c.Param("org_id")
				if orgIDStr == "" {
					orgIDStr = c.Request().Header.Get("X-Org-ID")
				}
				if orgIDStr == "" {
					orgIDStr = c.QueryParam("org_id")
				}

				if orgIDStr != "" {
					parsedOrgID, parseErr := uuid.Parse(orgIDStr)
					if parseErr == nil {
						org, err = orgRepo.GetByID(c.Request().Context(), parsedOrgID)
					}
				}
			}

			if err != nil || org == nil {
				return response.NotFound(c, "Organization not found. Specify valid X-Org-Slug or route slug")
			}

			// Check member relationship and role
			member, err := orgRepo.GetMember(c.Request().Context(), org.ID, userID)
			if err != nil || member == nil {
				return response.Forbidden(c, "You are not an active member of this organization")
			}

			if member.Status == domain.MemberStatusSuspended || member.Status == domain.MemberStatusRemoved {
				return response.Forbidden(c, "Your membership in this organization is suspended")
			}
			if member.Status == domain.MemberStatusPending {
				return response.Forbidden(c, "Your join request is pending approval")
			}

			c.Set(ContextKeyCurrentOrg, org)
			c.Set(ContextKeyCurrentMember, member)
			c.Set(ContextKeyMemberRole, member.Role)

			return next(c)
		}
	}
}

func RequireOrgAdmin() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			roleVal := c.Get(ContextKeyMemberRole)
			role, ok := roleVal.(domain.OrgRole)
			if !ok || role != domain.RoleOrgAdmin {
				return response.Forbidden(c, "Access denied: Organization Administrator privilege required")
			}
			return next(c)
		}
	}
}

func RequireOrgMember() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			roleVal := c.Get(ContextKeyMemberRole)
			role, ok := roleVal.(domain.OrgRole)
			if !ok || (role != domain.RoleOrgAdmin && role != domain.RoleMember) {
				return response.Forbidden(c, "Access denied: Organization member privilege required")
			}
			return next(c)
		}
	}
}

// Helpers

func GetUserID(c echo.Context) uuid.UUID {
	val := c.Get(ContextKeyUserID)
	if id, ok := val.(uuid.UUID); ok {
		return id
	}
	return uuid.Nil
}

func GetUserEmail(c echo.Context) string {
	val := c.Get(ContextKeyUserEmail)
	if email, ok := val.(string); ok {
		return email
	}
	return ""
}

func GetCurrentOrg(c echo.Context) *domain.Organization {
	val := c.Get(ContextKeyCurrentOrg)
	if org, ok := val.(*domain.Organization); ok {
		return org
	}
	return nil
}

func GetCurrentMember(c echo.Context) *domain.OrganizationMember {
	val := c.Get(ContextKeyCurrentMember)
	if m, ok := val.(*domain.OrganizationMember); ok {
		return m
	}
	return nil
}

func GetCurrentRole(c echo.Context) domain.OrgRole {
	val := c.Get(ContextKeyMemberRole)
	if r, ok := val.(domain.OrgRole); ok {
		return r
	}
	return domain.RoleMember
}
