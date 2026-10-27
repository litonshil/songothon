package handler

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type ContributionHandler struct {
	contribService *service.ContributionService
}

func NewContributionHandler(contribService *service.ContributionService) *ContributionHandler {
	return &ContributionHandler{contribService: contribService}
}

func (h *ContributionHandler) SubmitDeposit(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	userID := middleware.GetUserID(c)

	var req domain.SubmitDepositRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid deposit submission payload")
	}

	contrib, err := h.contribService.SubmitDeposit(c.Request().Context(), org.ID, userID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Deposit submitted successfully and is pending admin verification", contrib)
}

func (h *ContributionHandler) ListMyHistory(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	userID := middleware.GetUserID(c)

	list, err := h.contribService.ListUserContributions(c.Request().Context(), org.ID, userID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Personal contribution history retrieved", list)
}

func (h *ContributionHandler) ListPending(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	pending, err := h.contribService.ListPending(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Pending verification queue retrieved", pending)
}

func (h *ContributionHandler) ListAll(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	cycle := c.QueryParam("cycle")
	status := c.QueryParam("status")

	list, err := h.contribService.ListContributions(c.Request().Context(), org.ID, cycle, status)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Contributions retrieved", list)
}

func (h *ContributionHandler) ApproveDeposit(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	reviewerID := middleware.GetUserID(c)

	idStr := c.Param("id")
	contribID, err := uuid.Parse(idStr)
	if err != nil {
		return response.BadRequest(c, "Invalid contribution ID format")
	}

	approved, err := h.contribService.ApproveDeposit(c.Request().Context(), org.ID, contribID, reviewerID)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Deposit approved successfully and recorded in vault ledger", approved)
}

func (h *ContributionHandler) RejectDeposit(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	reviewerID := middleware.GetUserID(c)

	idStr := c.Param("id")
	contribID, err := uuid.Parse(idStr)
	if err != nil {
		return response.BadRequest(c, "Invalid contribution ID format")
	}

	var req domain.ReviewDepositRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid review payload")
	}

	rejected, err := h.contribService.RejectDeposit(c.Request().Context(), org.ID, contribID, reviewerID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Deposit rejected", rejected)
}
