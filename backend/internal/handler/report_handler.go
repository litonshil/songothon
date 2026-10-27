package handler

import (
	"github.com/labstack/echo/v4"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type ReportHandler struct {
	reportService *service.ReportService
}

func NewReportHandler(reportService *service.ReportService) *ReportHandler {
	return &ReportHandler{reportService: reportService}
}

func (h *ReportHandler) GetMemberDashboard(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	member := middleware.GetCurrentMember(c)

	if org == nil || member == nil {
		return response.Forbidden(c, "Invalid organization member context")
	}

	data, err := h.reportService.GetMemberDashboard(c.Request().Context(), org, member)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Member dashboard metrics retrieved", data)
}

func (h *ReportHandler) GetAdminDashboard(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	if org == nil {
		return response.Forbidden(c, "Invalid organization context")
	}

	data, err := h.reportService.GetAdminDashboard(c.Request().Context(), org)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Admin dashboard metrics retrieved", data)
}
