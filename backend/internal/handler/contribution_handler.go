package handler

import (
	"errors"
	"io"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

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

	isAdmin := middleware.GetCurrentRole(c) == domain.RoleOrgAdmin
	contrib, err := h.contribService.SubmitDeposit(c.Request().Context(), org.ID, userID, isAdmin, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	if contrib.Status == domain.ContributionStatusApproved {
		return response.Created(c, "Deposit recorded and approved successfully", contrib)
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

const bulkDepositMaxFileBytes = 5 << 20 // 5 MB

// BulkUploadDeposits accepts a multipart form with:
//   - file:           the .xlsx sheet (Email column + YYYY-MM cycle columns)
//   - payment_method: optional, defaults to "cash"
//   - dry_run:        "true" to validate and preview without writing anything
func (h *ContributionHandler) BulkUploadDeposits(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)

	fh, err := c.FormFile("file")
	if err != nil {
		return response.BadRequest(c, `Attach the spreadsheet as the "file" form field`)
	}
	if !strings.EqualFold(filepath.Ext(fh.Filename), ".xlsx") {
		return response.BadRequest(c, "Only .xlsx files are supported")
	}
	if fh.Size > bulkDepositMaxFileBytes {
		return response.BadRequest(c, "File is too large; the limit is 5 MB")
	}

	src, err := fh.Open()
	if err != nil {
		return response.BadRequest(c, "Could not read the uploaded file")
	}
	defer src.Close()

	dryRun, _ := strconv.ParseBool(c.FormValue("dry_run"))
	opts := service.BulkDepositOptions{
		PaymentMethod: domain.PaymentMethod(strings.TrimSpace(c.FormValue("payment_method"))),
		DryRun:        dryRun,
		FileName:      filepath.Base(fh.Filename),
	}

	result, err := h.contribService.BulkUploadDeposits(c.Request().Context(), org.ID, adminID, io.LimitReader(src, bulkDepositMaxFileBytes), opts)
	if errors.Is(err, service.ErrBulkDepositInvalid) {
		return c.JSON(http.StatusUnprocessableEntity, response.APIResponse{
			Success: false,
			Error:   err.Error(),
			Data:    result,
		})
	}
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	switch {
	case dryRun:
		return response.Success(c, "Spreadsheet validated; review the preview and confirm to import", result)
	case result.Imported:
		return response.Created(c, "Deposits imported and approved successfully", result)
	default:
		return response.Success(c, "Nothing to import; every deposit in this sheet is already recorded", result)
	}
}
