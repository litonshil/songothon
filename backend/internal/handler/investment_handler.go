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

func (h *InvestmentHandler) CreateInvestment(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	creatorID := middleware.GetUserID(c)

	var req domain.CreateInvestmentRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid investment payload")
	}

	inv, err := h.invService.CreateInvestment(c.Request().Context(), org.ID, creatorID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Investment recorded successfully", inv)
}

func (h *InvestmentHandler) ListInvestments(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.invService.ListInvestments(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Investments retrieved", list)
}

func (h *InvestmentHandler) GetByID(c echo.Context) error {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return response.BadRequest(c, "Invalid investment ID format")
	}

	inv, err := h.invService.GetByID(c.Request().Context(), id)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	if inv == nil {
		return response.NotFound(c, "Investment not found")
	}

	return response.Success(c, "Investment details retrieved", inv)
}

func (h *InvestmentHandler) UpdateInvestment(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	updaterID := middleware.GetUserID(c)

	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return response.BadRequest(c, "Invalid investment ID format")
	}

	var req domain.UpdateInvestmentRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid update payload")
	}

	updated, err := h.invService.UpdateInvestment(c.Request().Context(), org.ID, updaterID, id, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Investment updated successfully", updated)
}

func (h *InvestmentHandler) GetPortfolioMetrics(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	metrics, err := h.invService.GetPortfolioMetrics(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Portfolio metrics calculated", metrics)
}

func (h *InvestmentHandler) DeleteInvestment(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	deleterID := middleware.GetUserID(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return response.BadRequest(c, "Invalid investment ID format")
	}
	if err := h.invService.DeleteInvestment(c.Request().Context(), org.ID, deleterID, id); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Investment deleted successfully", nil)
}
