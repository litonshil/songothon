package handler

import (
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type ExpenseHandler struct {
	expService *service.ExpenseService
}

func NewExpenseHandler(expService *service.ExpenseService) *ExpenseHandler {
	return &ExpenseHandler{expService: expService}
}

func (h *ExpenseHandler) CreateExpense(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	recorderID := middleware.GetUserID(c)

	var req domain.CreateExpenseRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid expense payload")
	}

	expense, err := h.expService.CreateExpense(c.Request().Context(), org.ID, recorderID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Expense recorded successfully", expense)
}

func (h *ExpenseHandler) ListExpenses(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.expService.ListExpenses(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Expenses retrieved", list)
}
