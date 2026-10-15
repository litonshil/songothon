package handler

import (
	"github.com/labstack/echo/v4"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type ReportHandler struct {
	reportService *service.ReportService
}

func NewReportHandler(reportService *service.ReportService) *ReportHandler {
	return &ReportHandler{reportService: reportService}
}

// GetOverview returns aggregate pool statistics (Read-only for all members & admins)
func (h *ReportHandler) GetOverview(c echo.Context) error {
	overview, err := h.reportService.GetPoolOverview(c.Request().Context())
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Pool overview retrieved successfully", overview)
}

// GetFinancialSummary returns detailed organization audit and financial breakdown (Admin only)
func (h *ReportHandler) GetFinancialSummary(c echo.Context) error {
	summary, err := h.reportService.GetFinancialSummary(c.Request().Context())
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Financial summary report retrieved successfully", summary)
}
