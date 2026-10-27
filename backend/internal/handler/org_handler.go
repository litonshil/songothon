package handler

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type OrgHandler struct {
	orgService *service.OrgService
}

func NewOrgHandler(orgService *service.OrgService) *OrgHandler {
	return &OrgHandler{orgService: orgService}
}

func (h *OrgHandler) CreateOrg(c echo.Context) error {
	userID := middleware.GetUserID(c)
	var req domain.CreateOrganizationRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid organization payload")
	}

	org, err := h.orgService.CreateOrganization(c.Request().Context(), userID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Organization created successfully", org)
}

func (h *OrgHandler) ListMyOrgs(c echo.Context) error {
	userID := middleware.GetUserID(c)
	list, err := h.orgService.ListUserOrganizations(c.Request().Context(), userID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "User organizations retrieved", list)
}

func (h *OrgHandler) JoinOrg(c echo.Context) error {
	userID := middleware.GetUserID(c)
	var req domain.JoinOrganizationRequest
	if err := c.Bind(&req); err != nil || req.Slug == "" {
		return response.BadRequest(c, "Organization slug is required")
	}

	member, err := h.orgService.JoinBySlug(c.Request().Context(), userID, req.Slug)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Successfully joined organization", member)
}

func (h *OrgHandler) GetOrg(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	if org == nil {
		return response.NotFound(c, "Organization context missing")
	}
	return response.Success(c, "Organization details retrieved", org)
}

func (h *OrgHandler) InviteMember(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	inviterID := middleware.GetUserID(c)

	var req domain.InviteMemberRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid member invitation payload")
	}

	member, err := h.orgService.InviteMember(c.Request().Context(), org.ID, inviterID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Member added successfully", member)
}

func (h *OrgHandler) UpdateMember(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	updaterID := middleware.GetUserID(c)
	memberIDStr := c.Param("member_id")
	memberID, err := uuid.Parse(memberIDStr)
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}

	var req domain.UpdateMemberRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid update payload")
	}

	if err := h.orgService.UpdateMember(c.Request().Context(), org.ID, updaterID, memberID, &req); err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Member updated successfully", nil)
}

func (h *OrgHandler) ListMembers(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	viewerID := middleware.GetUserID(c)
	role := middleware.GetCurrentRole(c)
	members, err := h.orgService.ListMembers(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	// Members always see their own record and savings, but the admin controls
	// whether peers can be listed and whether peer savings are visible.
	if role != domain.RoleOrgAdmin {
		if !org.AllowPeerListVisibility {
			self := make([]domain.OrgMemberDetail, 0, 1)
			for _, m := range members {
				if m.UserID == viewerID {
					self = append(self, m)
					break
				}
			}
			members = self
		}
		if !org.AllowPeerFinancialVisibility {
			for i := range members {
				if members[i].UserID != viewerID {
					members[i].TotalSavings = nil
				}
			}
		}
	}

	return response.Success(c, "Members directory retrieved", members)
}

func (h *OrgHandler) UpdatePrivacy(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)

	var req domain.UpdateOrgPrivacyRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid privacy payload")
	}

	allowList := org.AllowPeerListVisibility
	allowFinancial := org.AllowPeerFinancialVisibility
	if req.AllowPeerListVisibility != nil {
		allowList = *req.AllowPeerListVisibility
	}
	if req.AllowPeerFinancialVisibility != nil {
		allowFinancial = *req.AllowPeerFinancialVisibility
	}

	if err := h.orgService.UpdatePrivacy(c.Request().Context(), org.ID, adminID, allowList, allowFinancial); err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Organization privacy settings updated", echo.Map{
		"allow_peer_list_visibility":      allowList,
		"allow_peer_financial_visibility": allowFinancial,
	})
}

func (h *OrgHandler) RemoveMember(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	updaterID := middleware.GetUserID(c)
	memberID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}
	if err := h.orgService.RemoveMember(c.Request().Context(), org.ID, updaterID, memberID); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Member removed successfully", nil)
}

func (h *OrgHandler) ListJoinRequests(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.orgService.ListPendingJoinRequests(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "Pending join requests retrieved", list)
}

func (h *OrgHandler) ApproveJoinRequest(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)
	userID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}
	if err := h.orgService.ApproveJoinRequest(c.Request().Context(), org.ID, adminID, userID); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Join request approved", nil)
}

func (h *OrgHandler) RejectJoinRequest(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)
	userID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}
	if err := h.orgService.RejectJoinRequest(c.Request().Context(), org.ID, adminID, userID); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Join request rejected", nil)
}

func (h *OrgHandler) ListInvitations(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.orgService.ListInvitations(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "Pending invitations retrieved", list)
}

func (h *OrgHandler) ConfigureShares(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)

	var req domain.ConfigureSharesRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid share configuration payload")
	}

	if err := h.orgService.ConfigureShares(c.Request().Context(), org.ID, adminID, &req); err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Share configuration updated successfully", nil)
}

func (h *OrgHandler) CreateDownPaymentScheme(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)

	var req domain.CreateDownPaymentSchemeRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid down payment payload")
	}

	if err := h.orgService.CreateDownPaymentScheme(c.Request().Context(), org.ID, adminID, &req); err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Down payment scheme created successfully", nil)
}

func (h *OrgHandler) ListDownPaymentSchemes(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	schemes, err := h.orgService.ListDownPaymentSchemes(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Down payment schemes retrieved", schemes)
}
