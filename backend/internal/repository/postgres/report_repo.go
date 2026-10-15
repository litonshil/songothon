package postgres

import (
	"context"
	"fmt"

	"songothon/internal/domain"
)

type ReportRepository struct {
	db *DB
}

func NewReportRepository(db *DB) *ReportRepository {
	return &ReportRepository{db: db}
}

func (r *ReportRepository) GetPoolMetrics(ctx context.Context) (*domain.PoolMetrics, error) {
	metrics := &domain.PoolMetrics{}

	// Total funds collected from member deposits
	err := r.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount), 0.00)
		FROM contributions
		WHERE status = 'paid'
	`).Scan(&metrics.TotalFundsCollected)
	if err != nil {
		return nil, fmt.Errorf("failed to query total funds collected: %w", err)
	}

	// Active investments: total invested, portfolio valuation, realized returns, count
	err = r.db.Pool.QueryRow(ctx, `
		SELECT 
			COALESCE(SUM(amount_invested), 0.00),
			COALESCE(SUM(current_valuation), 0.00),
			COALESCE(SUM(realized_returns), 0.00),
			COUNT(*)
		FROM investments
		WHERE status = 'active'
	`).Scan(&metrics.TotalInvested, &metrics.PortfolioValuation, &metrics.TotalReturns, &metrics.InvestmentsCount)
	if err != nil {
		return nil, fmt.Errorf("failed to query investments summary: %w", err)
	}

	// Active members count
	err = r.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM users
		WHERE role = 'member' AND status = 'active'
	`).Scan(&metrics.ActiveMembersCount)
	if err != nil {
		return nil, fmt.Errorf("failed to query active members count: %w", err)
	}

	// Available liquidity = Total Funds Collected + Realized Returns - Total Invested
	metrics.AvailableLiquidity = (metrics.TotalFundsCollected + metrics.TotalReturns) - metrics.TotalInvested
	if metrics.AvailableLiquidity < 0 {
		metrics.AvailableLiquidity = 0
	}

	return metrics, nil
}

func (r *ReportRepository) GetRecentTransactions(ctx context.Context, limit int) ([]domain.Transaction, error) {
	if limit <= 0 {
		limit = 20
	}

	query := `
		SELECT id, type, amount, flow, COALESCE(reference_table, ''), reference_id,
		       recorded_by, COALESCE(description, ''), created_at
		FROM transactions
		ORDER BY created_at DESC
		LIMIT $1
	`
	rows, err := r.db.Pool.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query recent transactions: %w", err)
	}
	defer rows.Close()

	var txs []domain.Transaction
	for rows.Next() {
		var tx domain.Transaction
		if err := rows.Scan(
			&tx.ID,
			&tx.Type,
			&tx.Amount,
			&tx.Flow,
			&tx.ReferenceTable,
			&tx.ReferenceID,
			&tx.RecordedBy,
			&tx.Description,
			&tx.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan transaction: %w", err)
		}
		txs = append(txs, tx)
	}

	return txs, nil
}

func (r *ReportRepository) GetSectorBreakdown(ctx context.Context) ([]domain.SectorMetric, error) {
	query := `
		SELECT sector, COALESCE(SUM(amount_invested), 0.00) as total_alloc
		FROM investments
		WHERE status = 'active'
		GROUP BY sector
		ORDER BY total_alloc DESC
	`
	rows, err := r.db.Pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query sector breakdown: %w", err)
	}
	defer rows.Close()

	var totalSum float64
	var rawBreakdown []struct {
		sector string
		amount float64
	}

	for rows.Next() {
		var s string
		var a float64
		if err := rows.Scan(&s, &a); err != nil {
			return nil, fmt.Errorf("failed to scan sector metric: %w", err)
		}
		rawBreakdown = append(rawBreakdown, struct {
			sector string
			amount float64
		}{sector: s, amount: a})
		totalSum += a
	}

	var results []domain.SectorMetric
	for _, item := range rawBreakdown {
		pct := 0.0
		if totalSum > 0 {
			pct = (item.amount / totalSum) * 100.0
		}
		results = append(results, domain.SectorMetric{
			Sector:     item.sector,
			TotalAlloc: item.amount,
			Percentage: pct,
		})
	}

	return results, nil
}
