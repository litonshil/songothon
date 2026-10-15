package middleware

import (
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/pkg/response"
	"songothon/pkg/token"
)

const (
	ContextUserIDKey    = "user_id"
	ContextUserEmailKey = "user_email"
	ContextUserRoleKey  = "user_role"
	ContextClaimsKey    = "jwt_claims"
)

// AuthMiddleware validates JWT Bearer token and populates user info in Echo context
func AuthMiddleware(tm *token.TokenManager) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return response.Unauthorized(c, "Authorization header is missing")
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				return response.Unauthorized(c, "Authorization header format must be 'Bearer <token>'")
			}

			claims, err := tm.ValidateToken(parts[1])
			if err != nil {
				return response.Unauthorized(c, "Invalid or expired authorization token")
			}

			// Store in context for downstream handlers
			c.Set(ContextUserIDKey, claims.UserID)
			c.Set(ContextUserEmailKey, claims.Email)
			c.Set(ContextUserRoleKey, claims.Role)
			c.Set(ContextClaimsKey, claims)

			return next(c)
		}
	}
}

// RequireRole ensures that the authenticated user has one of the specified roles
func RequireRole(allowedRoles ...domain.Role) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			roleVal := c.Get(ContextUserRoleKey)
			if roleVal == nil {
				return response.Unauthorized(c, "User authentication required")
			}

			userRole, ok := roleVal.(domain.Role)
			if !ok {
				return response.Forbidden(c, "Invalid user role credentials")
			}

			for _, allowed := range allowedRoles {
				if userRole == allowed {
					return next(c)
				}
			}

			return response.Forbidden(c, "Access denied: insufficient permissions for this operation")
		}
	}
}

// Context Helpers
func GetCurrentUserID(c echo.Context) (uuid.UUID, error) {
	val := c.Get(ContextUserIDKey)
	if val == nil {
		return uuid.Nil, errors.New("user ID missing from context")
	}
	id, ok := val.(uuid.UUID)
	if !ok {
		return uuid.Nil, errors.New("invalid user ID type in context")
	}
	return id, nil
}

func GetCurrentUserRole(c echo.Context) domain.Role {
	val := c.Get(ContextUserRoleKey)
	if val == nil {
		return ""
	}
	if role, ok := val.(domain.Role); ok {
		return role
	}
	return ""
}
