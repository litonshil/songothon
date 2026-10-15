package handler

import (
	"strconv"

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

// CreatePeriod creates a savings cycle / contribution deadline (Admin)
func (h *ContributionHandler) CreatePeriod(c echo.Context) error {
	var req domain.CreatePeriodRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request payload")
	}

	period, err := h.contribService.CreatePeriod(c.Request().Context(), &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Contribution period created successfully", period)
}

// ListPeriods lists contribution cycles (All Authenticated)
func (h *ContributionHandler) ListPeriods(c echo.Context) error {
	activeOnly := c.QueryParam("active") == "true"
	periods, err := h.contribService.ListPeriods(c.Request().Context(), activeOnly)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Periods retrieved successfully", periods)
}

// SubmitDeposit allows a member to submit their monthly deposit (Member)
func (h *ContributionHandler) SubmitDeposit(c echo.Context) error {
	userID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "Member session required")
	}

	var req domain.SubmitDepositRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid deposit payload")
	}

	contrib, err := h.contribService.SubmitDeposit(c.Request().Context(), userID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Deposit entry submitted successfully. Awaiting admin approval.", contrib)
}

// ApproveDeposit approves a pending member deposit (Admin only)
func (h *ContributionHandler) ApproveDeposit(c echo.Context) error {
	adminID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "Admin session required")
	}

	depositID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return response.BadRequest(c, "Invalid deposit ID")
	}

	approved, err := h.contribService.ApproveDeposit(c.Request().Context(), depositID, adminID)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Deposit approved and marked as paid in financial ledger", approved)
}

// RejectDeposit rejects a pending member deposit (Admin only)
func (h *ContributionHandler) RejectDeposit(c echo.Context) error {
	adminID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "Admin session required")
	}

	depositID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return response.BadRequest(c, "Invalid deposit ID")
	}

	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.Bind(&body)
	if body.Reason == "" {
		body.Reason = "Transaction ID could not be verified"
	}

	if err := h.contribService.RejectDeposit(c.Request().Context(), depositID, adminID, body.Reason); err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Success(c, "Deposit rejected", nil)
}

// ListPendingApprovals lists deposits awaiting admin approval (Admin only)
func (h *ContributionHandler) ListPendingApprovals(c echo.Context) error {
	pending, err := h.contribService.ListPendingApprovals(c.Request().Context())
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Pending deposits retrieved successfully", pending)
}

// GetMonthlyReport returns deposits for a month/period (All Authenticated)
func (h *ContributionHandler) GetMonthlyReport(c echo.Context) error {
	var periodID *uuid.UUID
	periodStr := c.QueryParam("period_id")
	if periodStr != "" {
		parsed, err := uuid.Parse(periodStr)
		if err == nil {
			periodID = &parsed
		}
	}

	report, err := h.contribService.GetMonthlyDepositReport(c.Request().Context(), periodID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Monthly deposit report retrieved successfully", report)
}

// ListAllMonthlyReports returns all monthly cycles and who paid (All Authenticated)
func (h *ContributionHandler) ListAllMonthlyReports(c echo.Context) error {
	reports, err := h.contribService.ListAllMonthlyReports(c.Request().Context())
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "All monthly reports retrieved successfully", reports)
}

// RecordDeposit records a member deposit payment directly (Admin)
func (h *ContributionHandler) RecordDeposit(c echo.Context) error {
	adminID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "Admin session required")
	}

	var req domain.RecordDepositRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request payload")
	}

	contrib, err := h.contribService.RecordDeposit(c.Request().Context(), adminID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Deposit recorded successfully in ledger", contrib)
}

// ListAllContributions lists all pool deposits (Admin)
func (h *ContributionHandler) ListAllContributions(c echo.Context) error {
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	offset, _ := strconv.Atoi(c.QueryParam("offset"))

	list, err := h.contribService.ListAllContributions(c.Request().Context(), limit, offset)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Contributions retrieved successfully", list)
}

// GetMyHistory retrieves logged-in member's personal deposit history (Member)
func (h *ContributionHandler) GetMyHistory(c echo.Context) error {
	userID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "User authentication required")
	}

	history, err := h.contribService.ListUserContributions(c.Request().Context(), userID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Deposit history retrieved successfully", history)
}

// GetMyDues retrieves logged-in member's pending dues and contribution statistics (Member)
func (h *ContributionHandler) GetMyDues(c echo.Context) error {
	userID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "User authentication required")
	}

	summary, err := h.contribService.GetUserFinancialSummary(c.Request().Context(), userID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Personal financial summary retrieved successfully", summary)
}

// GetMemberFinancialSummary allows admin to inspect specific member's dues
func (h *ContributionHandler) GetMemberFinancialSummary(c echo.Context) error {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return response.BadRequest(c, "Invalid member ID format")
	}

	summary, err := h.contribService.GetUserFinancialSummary(c.Request().Context(), targetID)
	if err != nil {
		return response.NotFound(c, err.Error())
	}

	return response.Success(c, "Member dues summary retrieved successfully", summary)
}
