package handler

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type SettlementHandler struct {
	settlementService *service.SettlementService
}

func NewSettlementHandler(settlementService *service.SettlementService) *SettlementHandler {
	return &SettlementHandler{settlementService: settlementService}
}

// PreviewSettlement shows what a member would be paid if settled now.
func (h *SettlementHandler) PreviewSettlement(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)
	userID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}
	preview, _, err := h.settlementService.Preview(c.Request().Context(), org, adminID, userID)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Settlement preview calculated", preview)
}

// SettleMember pays the member out and ends their membership.
func (h *SettlementHandler) SettleMember(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)
	userID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}
	var req domain.SettleMemberRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid settlement payload")
	}
	settlement, err := h.settlementService.Settle(c.Request().Context(), org, adminID, userID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Created(c, "Member settled successfully", settlement)
}

func (h *SettlementHandler) ListSettlements(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.settlementService.List(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "Settlements retrieved", list)
}
