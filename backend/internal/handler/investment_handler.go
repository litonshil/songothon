package handler

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type InvestmentHandler struct {
	invService *service.InvestmentService
}

func NewInvestmentHandler(invService *service.InvestmentService) *InvestmentHandler {
	return &InvestmentHandler{invService: invService}
}

// CreateInvestment records a new collective investment (Admin only)
func (h *InvestmentHandler) CreateInvestment(c echo.Context) error {
	adminID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "Admin session required")
	}

	var req domain.CreateInvestmentRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request payload")
	}

	inv, err := h.invService.CreateInvestment(c.Request().Context(), adminID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Investment recorded successfully", inv)
}

// UpdateInvestment updates returns, valuation, or status of an investment (Admin only)
func (h *InvestmentHandler) UpdateInvestment(c echo.Context) error {
	idParam := c.Param("id")
	invID, err := uuid.Parse(idParam)
	if err != nil {
		return response.BadRequest(c, "Invalid investment ID format")
	}

	var req domain.UpdateInvestmentRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request payload")
	}

	updated, err := h.invService.UpdateInvestment(c.Request().Context(), invID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Investment updated successfully", updated)
}

// GetByID returns details of a single investment (All Authenticated)
func (h *InvestmentHandler) GetByID(c echo.Context) error {
	idParam := c.Param("id")
	invID, err := uuid.Parse(idParam)
	if err != nil {
		return response.BadRequest(c, "Invalid investment ID format")
	}

	inv, err := h.invService.GetInvestmentByID(c.Request().Context(), invID)
	if err != nil {
		return response.NotFound(c, err.Error())
	}

	return response.Success(c, "Investment retrieved successfully", inv)
}

// ListInvestments returns portfolio investments (All Authenticated - Read-Only for members)
func (h *InvestmentHandler) ListInvestments(c echo.Context) error {
	status := c.QueryParam("status")
	sector := c.QueryParam("sector")

	investments, err := h.invService.ListInvestments(c.Request().Context(), status, sector)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Investments retrieved successfully", investments)
}
