package handler

import (
	"songothon/internal/domain"
	"songothon/internal/service"
	"songothon/pkg/response"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type MemberHandler struct {
	memberService *service.MemberService
}

func NewMemberHandler(memberService *service.MemberService) *MemberHandler {
	return &MemberHandler{memberService: memberService}
}

func (h *MemberHandler) ListMembers(c echo.Context) error {
	status := c.QueryParam("status")
	members, err := h.memberService.ListMembers(c.Request().Context(), status)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Members retrieved successfully", members)
}

func (h *MemberHandler) UpdateStatus(c echo.Context) error {
	idParam := c.Param("id")
	userID, err := uuid.Parse(idParam)
	if err != nil {
		return response.BadRequest(c, "Invalid user ID format")
	}

	var req domain.UpdateUserStatusRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request body")
	}

	if err := h.memberService.UpdateMemberStatus(c.Request().Context(), userID, req.Status); err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Member status updated successfully", nil)
}
