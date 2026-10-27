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

type IncomeService struct {
	incRepo   *postgres.IncomeRepository
	auditRepo *postgres.AuditRepository
}

func NewIncomeService(
	incRepo *postgres.IncomeRepository,
	auditRepo *postgres.AuditRepository,
) *IncomeService {
	return &IncomeService{
		incRepo:   incRepo,
		auditRepo: auditRepo,
	}
}

func (s *IncomeService) CreateIncome(
	ctx context.Context,
	orgID, recorderID uuid.UUID,
	req *domain.CreateIncomeRequest,
) (*domain.Income, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errors.New("income title is required")
	}

	if req.Amount <= 0 {
		return nil, errors.New("income amount must be greater than zero")
	}

	category := strings.TrimSpace(req.Category)
	if category == "" {
		category = "general"
	}

	incDate := time.Now()
	if strings.TrimSpace(req.IncomeDate) != "" {
		parsed, err := time.Parse("2006-01-02", strings.TrimSpace(req.IncomeDate))
		if err != nil {
			return nil, errors.New("income date must be in YYYY-MM-DD format")
		}
		incDate = parsed
	}

	income := &domain.Income{
		OrgID:      orgID,
		Title:      title,
		Category:   category,
		Amount:     req.Amount,
		IncomeDate: incDate,
		Notes:      strings.TrimSpace(req.Notes),
		RecordedBy: &recorderID,
	}

	if err := s.incRepo.Create(ctx, income); err != nil {
		return nil, fmt.Errorf("failed to create income: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &recorderID,
		Action:     "CREATE_INCOME",
		EntityType: "incomes",
		EntityID:   &income.ID,
		DetailsJSON: map[string]interface{}{
			"title":    title,
			"category": category,
			"amount":   req.Amount,
		},
	})

	return income, nil
}

func (s *IncomeService) ListIncomes(ctx context.Context, orgID uuid.UUID) ([]domain.Income, error) {
	return s.incRepo.ListByOrg(ctx, orgID)
}
