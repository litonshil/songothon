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

type ExpenseService struct {
	expRepo   *postgres.ExpenseRepository
	auditRepo *postgres.AuditRepository
}

func NewExpenseService(
	expRepo *postgres.ExpenseRepository,
	auditRepo *postgres.AuditRepository,
) *ExpenseService {
	return &ExpenseService{
		expRepo:   expRepo,
		auditRepo: auditRepo,
	}
}

func (s *ExpenseService) CreateExpense(
	ctx context.Context,
	orgID, recorderID uuid.UUID,
	req *domain.CreateExpenseRequest,
) (*domain.Expense, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errors.New("expense title is required")
	}

	if req.Amount <= 0 {
		return nil, errors.New("expense amount must be greater than zero")
	}

	category := strings.TrimSpace(req.Category)
	if category == "" {
		category = "general"
	}

	expDate := time.Now()
	if strings.TrimSpace(req.ExpenseDate) != "" {
		parsed, err := time.Parse("2006-01-02", strings.TrimSpace(req.ExpenseDate))
		if err != nil {
			return nil, errors.New("expense date must be in YYYY-MM-DD format")
		}
		expDate = parsed
	}

	expense := &domain.Expense{
		OrgID:       orgID,
		Title:       title,
		Category:    category,
		Amount:      req.Amount,
		ExpenseDate: expDate,
		Notes:       strings.TrimSpace(req.Notes),
		RecordedBy:  &recorderID,
	}

	if err := s.expRepo.Create(ctx, expense); err != nil {
		return nil, fmt.Errorf("failed to create expense: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &recorderID,
		Action:     "CREATE_EXPENSE",
		EntityType: "expenses",
		EntityID:   &expense.ID,
		DetailsJSON: map[string]interface{}{
			"title":    title,
			"category": category,
			"amount":   req.Amount,
		},
	})

	return expense, nil
}

func (s *ExpenseService) ListExpenses(ctx context.Context, orgID uuid.UUID) ([]domain.Expense, error) {
	return s.expRepo.ListByOrg(ctx, orgID)
}
