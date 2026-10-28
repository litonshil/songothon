package handler

import (
	"time"

	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
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

const collectionsHiddenMessage = "Collection list is hidden by the organization admin"

func canViewCollections(org *domain.Organization, member *domain.OrganizationMember) bool {
	return member.Role == domain.RoleOrgAdmin || org.AllowMemberCollectionVisibility
}

func (h *ReportHandler) ListCollections(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	member := middleware.GetCurrentMember(c)
	if org == nil || member == nil {
		return response.Forbidden(c, "Invalid organization member context")
	}
	if !canViewCollections(org, member) {
		return response.Forbidden(c, collectionsHiddenMessage)
	}

	data, err := h.reportService.ListCycleCollections(c.Request().Context(), org)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Cycle collections retrieved", data)
}

func (h *ReportHandler) GetCollectionCycle(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	member := middleware.GetCurrentMember(c)
	if org == nil || member == nil {
		return response.Forbidden(c, "Invalid organization member context")
	}

	if !canViewCollections(org, member) {
		return response.Forbidden(c, collectionsHiddenMessage)
	}

	cycle := c.Param("cycle")
	if _, err := time.Parse("2006-01", cycle); err != nil {
		return response.BadRequest(c, "cycle must be in YYYY-MM format")
	}

	data, err := h.reportService.GetCycleCollection(c.Request().Context(), org, member, cycle)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Cycle collection retrieved", data)
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
