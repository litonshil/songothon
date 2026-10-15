package service

import (
	"context"

	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type ReportService struct {
	reportRepo *postgres.ReportRepository
}

func NewReportService(reportRepo *postgres.ReportRepository) *ReportService {
	return &ReportService{reportRepo: reportRepo}
}

func (s *ReportService) GetPoolOverview(ctx context.Context) (*domain.PoolMetrics, error) {
	return s.reportRepo.GetPoolMetrics(ctx)
}

func (s *ReportService) GetFinancialSummary(ctx context.Context) (*domain.FinancialSummaryReport, error) {
	metrics, err := s.reportRepo.GetPoolMetrics(ctx)
	if err != nil {
		return nil, err
	}

	recentTxs, err := s.reportRepo.GetRecentTransactions(ctx, 15)
	if err != nil {
		recentTxs = []domain.Transaction{}
	}

	sectors, err := s.reportRepo.GetSectorBreakdown(ctx)
	if err != nil {
		sectors = []domain.SectorMetric{}
	}

	return &domain.FinancialSummaryReport{
		Metrics:       *metrics,
		RecentLedger:  recentTxs,
		TopSectorList: sectors,
	}, nil
}
