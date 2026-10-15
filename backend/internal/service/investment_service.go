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

type InvestmentService struct {
	invRepo *postgres.InvestmentRepository
}

func NewInvestmentService(invRepo *postgres.InvestmentRepository) *InvestmentService {
	return &InvestmentService{invRepo: invRepo}
}

func (s *InvestmentService) CreateInvestment(ctx context.Context, adminID uuid.UUID, req *domain.CreateInvestmentRequest) (*domain.Investment, error) {
	// Title / Where we invest
	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = strings.TrimSpace(req.Name)
	}
	if title == "" {
		return nil, errors.New("investment title (where we invest) is required")
	}

	// Amount
	amount := req.Amount
	if amount <= 0 {
		amount = req.AmountInvested
	}
	if amount <= 0 {
		return nil, errors.New("investment amount must be greater than 0")
	}

	// Duration
	duration := strings.TrimSpace(req.Duration)
	if duration == "" {
		duration = "1 Year"
	}

	invDate := time.Now()
	if req.InvestmentDate != "" {
		if parsed, err := time.Parse("2006-01-02", req.InvestmentDate); err == nil {
			invDate = parsed
		}
	}

	sector := strings.TrimSpace(req.Sector)
	if sector == "" {
		sector = "General"
	}

	inv := &domain.Investment{
		Name:             title,
		Sector:           sector,
		AmountInvested:   amount,
		Duration:         duration,
		CurrentValuation: amount,
		Status:           domain.InvestmentStatusActive,
		InvestmentDate:   invDate,
		Notes:            req.Notes,
		CreatedBy:        &adminID,
	}

	return s.invRepo.Create(ctx, inv)
}

func (s *InvestmentService) UpdateInvestment(ctx context.Context, id uuid.UUID, req *domain.UpdateInvestmentRequest) (*domain.Investment, error) {
	existing, err := s.invRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, errors.New("investment not found")
	}

	if req.Title != nil && *req.Title != "" {
		existing.Name = *req.Title
	} else if req.Name != nil && *req.Name != "" {
		existing.Name = *req.Name
	}

	if req.Amount != nil && *req.Amount > 0 {
		existing.AmountInvested = *req.Amount
		existing.CurrentValuation = *req.Amount
	}

	if req.Duration != nil && *req.Duration != "" {
		existing.Duration = *req.Duration
	}

	if req.Status != nil {
		existing.Status = *req.Status
	}
	if req.Notes != nil {
		existing.Notes = *req.Notes
	}

	return s.invRepo.Update(ctx, id, existing)
}

func (s *InvestmentService) GetInvestmentByID(ctx context.Context, id uuid.UUID) (*domain.Investment, error) {
	inv, err := s.invRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if inv == nil {
		return nil, errors.New("investment not found")
	}
	return inv, nil
}

func (s *InvestmentService) ListInvestments(ctx context.Context, status, sector string) ([]domain.Investment, error) {
	return s.invRepo.List(ctx, status, sector)
}
