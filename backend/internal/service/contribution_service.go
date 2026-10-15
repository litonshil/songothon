package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type ContributionService struct {
	contribRepo *postgres.ContributionRepository
	userRepo    *postgres.UserRepository
}

func NewContributionService(contribRepo *postgres.ContributionRepository, userRepo *postgres.UserRepository) *ContributionService {
	return &ContributionService{
		contribRepo: contribRepo,
		userRepo:    userRepo,
	}
}

func (s *ContributionService) CreatePeriod(ctx context.Context, req *domain.CreatePeriodRequest) (*domain.ContributionPeriod, error) {
	if req.Title == "" {
		return nil, errors.New("period title is required")
	}
	if req.AmountDue <= 0 {
		return nil, errors.New("amount due must be greater than 0")
	}

	dueDate, err := time.Parse("2006-01-02", req.DueDate)
	if err != nil {
		return nil, errors.New("invalid due_date format, must be YYYY-MM-DD")
	}

	period := &domain.ContributionPeriod{
		Title:     req.Title,
		Frequency: req.Frequency,
		AmountDue: req.AmountDue,
		DueDate:   dueDate,
		IsActive:  true,
	}

	return s.contribRepo.CreatePeriod(ctx, period)
}

func (s *ContributionService) ListPeriods(ctx context.Context, activeOnly bool) ([]domain.ContributionPeriod, error) {
	return s.contribRepo.ListPeriods(ctx, activeOnly)
}

// SubmitDeposit allows a member to submit their monthly deposit (Status: Pending admin approval)
func (s *ContributionService) SubmitDeposit(ctx context.Context, userID uuid.UUID, req *domain.SubmitDepositRequest) (*domain.Contribution, error) {
	trxID := strings.TrimSpace(req.TransactionID)
	if trxID == "" {
		return nil, errors.New("transaction_id (TrxID from bKash/Nagad/Bank) is required")
	}

	method := strings.TrimSpace(strings.ToLower(req.PaymentMethod))
	if method == "" {
		method = "bkash"
	}

	// Determine period and predefined amount
	periodID := req.PeriodID
	var predefinedAmount float64

	if periodID == nil || *periodID == uuid.Nil {
		activePeriod, err := s.contribRepo.GetActivePeriod(ctx)
		if err != nil || activePeriod == nil {
			// Fallback: list latest period
			periods, _ := s.contribRepo.ListPeriods(ctx, false)
			if len(periods) > 0 {
				periodID = &periods[0].ID
				predefinedAmount = periods[0].AmountDue
			}
		} else {
			periodID = &activePeriod.ID
			predefinedAmount = activePeriod.AmountDue
		}
	} else {
		period, err := s.contribRepo.GetPeriodByID(ctx, *periodID)
		if err == nil && period != nil {
			predefinedAmount = period.AmountDue
		}
	}

	amount := req.Amount
	if amount <= 0 {
		amount = predefinedAmount
	}
	if amount <= 0 {
		amount = 200.00 // standard default predefined deposit
	}

	contrib := &domain.Contribution{
		UserID:        userID,
		PeriodID:      periodID,
		Amount:        amount,
		PaymentMethod: method,
		ReferenceNo:   trxID,
		Status:        domain.ContributionPending,
		PaidAt:        time.Now(),
		Notes:         req.Notes,
	}

	return s.contribRepo.SubmitDeposit(ctx, contrib)
}

// ApproveDeposit approves a pending deposit and posts it to ledger (Admin only)
func (s *ContributionService) ApproveDeposit(ctx context.Context, contributionID, adminID uuid.UUID) (*domain.Contribution, error) {
	return s.contribRepo.ApproveDeposit(ctx, contributionID, adminID)
}

// RejectDeposit rejects a pending deposit (Admin only)
func (s *ContributionService) RejectDeposit(ctx context.Context, contributionID, adminID uuid.UUID, reason string) error {
	return s.contribRepo.RejectDeposit(ctx, contributionID, adminID, reason)
}

// ListPendingApprovals lists all deposits awaiting admin approval
func (s *ContributionService) ListPendingApprovals(ctx context.Context) ([]domain.Contribution, error) {
	return s.contribRepo.ListPendingApprovals(ctx)
}

// GetMonthlyDepositReport returns month-wise deposits for a given period or latest active period
func (s *ContributionService) GetMonthlyDepositReport(ctx context.Context, periodID *uuid.UUID) (*domain.MonthlyDepositReport, error) {
	var targetPeriodID uuid.UUID
	if periodID != nil && *periodID != uuid.Nil {
		targetPeriodID = *periodID
	} else {
		activePeriod, err := s.contribRepo.GetActivePeriod(ctx)
		if err != nil || activePeriod == nil {
			periods, err := s.contribRepo.ListPeriods(ctx, false)
			if err != nil || len(periods) == 0 {
				return nil, errors.New("no contribution period found")
			}
			targetPeriodID = periods[0].ID
		} else {
			targetPeriodID = activePeriod.ID
		}
	}

	return s.contribRepo.ListMonthlyDeposits(ctx, targetPeriodID)
}

// ListAllMonthlyReports returns all monthly cycles with their member deposits
func (s *ContributionService) ListAllMonthlyReports(ctx context.Context) ([]domain.MonthlyDepositReport, error) {
	return s.contribRepo.ListAllMonthlyReports(ctx)
}

func (s *ContributionService) RecordDeposit(ctx context.Context, adminID uuid.UUID, req *domain.RecordDepositRequest) (*domain.Contribution, error) {
	if req.UserID == uuid.Nil {
		return nil, errors.New("valid user_id is required")
	}
	if req.Amount <= 0 {
		return nil, errors.New("amount must be greater than 0")
	}
	method := req.PaymentMethod
	if method == "" {
		method = "bank_transfer"
	}

	ref := req.TransactionID
	if ref == "" {
		ref = req.ReferenceNo
	}

	paidAt := time.Now()
	if req.PaidAt != "" {
		if parsed, err := time.Parse(time.RFC3339, req.PaidAt); err == nil {
			paidAt = parsed
		} else if parsedDate, errDate := time.Parse("2006-01-02", req.PaidAt); errDate == nil {
			paidAt = parsedDate
		}
	}

	contribution := &domain.Contribution{
		UserID:        req.UserID,
		PeriodID:      req.PeriodID,
		Amount:        req.Amount,
		PaymentMethod: method,
		ReferenceNo:   ref,
		Status:        domain.ContributionPaid,
		RecordedBy:    &adminID,
		PaidAt:        paidAt,
		Notes:         req.Notes,
	}

	return s.contribRepo.RecordDeposit(ctx, contribution)
}

func (s *ContributionService) ListUserContributions(ctx context.Context, userID uuid.UUID) ([]domain.Contribution, error) {
	return s.contribRepo.ListUserContributions(ctx, userID)
}

func (s *ContributionService) ListAllContributions(ctx context.Context, limit, offset int) ([]domain.Contribution, error) {
	return s.contribRepo.ListAllContributions(ctx, limit, offset)
}

func (s *ContributionService) GetUserFinancialSummary(ctx context.Context, userID uuid.UUID) (*domain.MemberFinancialSummary, error) {
	return s.contribRepo.GetUserFinancialSummary(ctx, userID)
}
