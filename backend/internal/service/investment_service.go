package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type InvestmentService struct {
	invRepo   *postgres.InvestmentRepository
	auditRepo *postgres.AuditRepository
}

func NewInvestmentService(
	invRepo *postgres.InvestmentRepository,
	auditRepo *postgres.AuditRepository,
) *InvestmentService {
	return &InvestmentService{
		invRepo:   invRepo,
		auditRepo: auditRepo,
	}
}

func (s *InvestmentService) CreateInvestment(
	ctx context.Context,
	orgID, creatorID uuid.UUID,
	req *domain.CreateInvestmentRequest,
) (*domain.Investment, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errors.New("investment title is required")
	}

	category := strings.TrimSpace(req.Category)
	if category == "" {
		return nil, errors.New("investment category is required")
	}

	if req.InvestedCapital <= 0 {
		return nil, errors.New("invested capital must be greater than zero")
	}

	invDate, err := time.Parse("2006-01-02", req.InvestmentDate)
	if err != nil {
		invDate = time.Now()
	}

	var matDate *time.Time
	if req.MaturityDate != nil && *req.MaturityDate != "" {
		parsedMatDate, err := time.Parse("2006-01-02", *req.MaturityDate)
		if err == nil {
			matDate = &parsedMatDate
		}
	}

	currentVal := req.InvestedCapital
	if req.CurrentValuation != nil && *req.CurrentValuation > 0 {
		currentVal = *req.CurrentValuation
	}

	inv := &domain.Investment{
		OrgID:            orgID,
		Title:            title,
		Category:         category,
		InvestedCapital:  req.InvestedCapital,
		CurrentValuation: currentVal,
		ExpectedROI:      req.ExpectedROI,
		RealizedReturns:  0.0,
		Tenure:           strings.TrimSpace(req.Tenure),
		Notes:            req.Notes,
		Status:           domain.InvestmentStatusActive,
		InvestmentDate:   invDate,
		MaturityDate:     matDate,
		CreatedBy:        &creatorID,
	}

	if err := s.invRepo.Create(ctx, inv); err != nil {
		return nil, fmt.Errorf("failed to create investment: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &creatorID,
		Action:     "CREATE_INVESTMENT",
		EntityType: "investments",
		EntityID:   &inv.ID,
		DetailsJSON: map[string]interface{}{
			"title":            title,
			"category":         category,
			"invested_capital": req.InvestedCapital,
		},
	})

	return inv, nil
}

func (s *InvestmentService) ListInvestments(ctx context.Context, orgID uuid.UUID) ([]domain.Investment, error) {
	return s.invRepo.ListByOrg(ctx, orgID)
}

func (s *InvestmentService) GetByID(ctx context.Context, id uuid.UUID) (*domain.Investment, error) {
	return s.invRepo.GetByID(ctx, id)
}

func (s *InvestmentService) UpdateInvestment(
	ctx context.Context,
	orgID, updaterID, invID uuid.UUID,
	req *domain.UpdateInvestmentRequest,
) (*domain.Investment, error) {
	inv, err := s.invRepo.GetByID(ctx, invID)
	if err != nil {
		return nil, err
	}
	if inv == nil || inv.OrgID != orgID {
		return nil, errors.New("investment not found in this organization")
	}

	if req.Title != "" {
		inv.Title = strings.TrimSpace(req.Title)
	}
	if req.Category != "" {
		inv.Category = strings.TrimSpace(req.Category)
	}
	if req.CurrentValuation != nil {
		inv.CurrentValuation = *req.CurrentValuation
	}
	if req.ExpectedROI != nil {
		inv.ExpectedROI = *req.ExpectedROI
	}
	if req.RealizedReturns != nil {
		inv.RealizedReturns = *req.RealizedReturns
	}
	if req.Tenure != "" {
		inv.Tenure = strings.TrimSpace(req.Tenure)
	}
	if req.Notes != "" {
		inv.Notes = req.Notes
	}
	if req.Status != nil {
		inv.Status = *req.Status
	}
	if req.MaturityDate != nil && *req.MaturityDate != "" {
		parsedMatDate, err := time.Parse("2006-01-02", *req.MaturityDate)
		if err == nil {
			inv.MaturityDate = &parsedMatDate
		}
	}

	if err := s.invRepo.Update(ctx, inv); err != nil {
		return nil, fmt.Errorf("failed to update investment: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &updaterID,
		Action:     "UPDATE_INVESTMENT",
		EntityType: "investments",
		EntityID:   &inv.ID,
		DetailsJSON: map[string]interface{}{
			"status":            inv.Status,
			"current_valuation": inv.CurrentValuation,
			"realized_returns":  inv.RealizedReturns,
		},
	})

	return inv, nil
}

func (s *InvestmentService) GetPortfolioMetrics(ctx context.Context, orgID uuid.UUID) (*domain.PortfolioMetrics, error) {
	return s.invRepo.GetPortfolioMetrics(ctx, orgID)
}

func (s *InvestmentService) DeleteInvestment(ctx context.Context, orgID, deleterID, invID uuid.UUID) error {
	inv, err := s.invRepo.GetByID(ctx, invID)
	if err != nil {
		return err
	}
	if inv == nil || inv.OrgID != orgID {
		return errors.New("investment not found in this organization")
	}
	if err := s.invRepo.Delete(ctx, orgID, invID); err != nil {
		return err
	}
	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &deleterID,
		Action:     "DELETE_INVESTMENT",
		EntityType: "investments",
		EntityID:   &invID,
	})
	return nil
}
