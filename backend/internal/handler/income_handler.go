package handler

import (
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type IncomeHandler struct {
	incService *service.IncomeService
}

func NewIncomeHandler(incService *service.IncomeService) *IncomeHandler {
	return &IncomeHandler{incService: incService}
}

func (h *IncomeHandler) CreateIncome(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	recorderID := middleware.GetUserID(c)

	var req domain.CreateIncomeRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid income payload")
	}

	income, err := h.incService.CreateIncome(c.Request().Context(), org.ID, recorderID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Income recorded successfully", income)
}

func (h *IncomeHandler) ListIncomes(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.incService.ListIncomes(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Incomes retrieved", list)
}
