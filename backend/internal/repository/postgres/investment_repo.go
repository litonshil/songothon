package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"songothon/internal/domain"
)

type InvestmentRepository struct {
	db *DB
}

func NewInvestmentRepository(db *DB) *InvestmentRepository {
	return &InvestmentRepository{db: db}
}

func (r *InvestmentRepository) Create(ctx context.Context, inv *domain.Investment) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if inv.ID == uuid.Nil {
		inv.ID = uuid.New()
	}
	if inv.Status == "" {
		inv.Status = domain.InvestmentStatusActive
	}
	if inv.CurrentValuation == 0 {
		inv.CurrentValuation = inv.InvestedCapital
	}

	query := `
		INSERT INTO investments (
			id, org_id, title, category, invested_capital, current_valuation,
			expected_roi, realized_returns, tenure, notes, status,
			investment_date, maturity_date, created_by, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11,
			$12, $13, $14, NOW(), NOW()
		)
		RETURNING created_at, updated_at
	`
	err = tx.QueryRow(ctx, query,
		inv.ID, inv.OrgID, inv.Title, inv.Category, inv.InvestedCapital, inv.CurrentValuation,
		inv.ExpectedROI, inv.RealizedReturns, inv.Tenure, inv.Notes, inv.Status,
		inv.InvestmentDate, inv.MaturityDate, inv.CreatedBy,
	).Scan(&inv.CreatedAt, &inv.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert investment: %w", err)
	}

	// Record disbursement in transactions ledger (capital outflow)
	ledgerQuery := `
		INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description, created_at)
		VALUES ($1, $2, 'investment_disbursement', $3, 'outflow', 'investments', $4, $5, $6, NOW())
	`
	desc := fmt.Sprintf("Capital deployment for investment: %s", inv.Title)
	_, err = tx.Exec(ctx, ledgerQuery, uuid.New(), inv.OrgID, inv.InvestedCapital, inv.ID, inv.CreatedBy, desc)
	if err != nil {
		return fmt.Errorf("failed to record investment disbursement ledger: %w", err)
	}

	return tx.Commit(ctx)
}

func (r *InvestmentRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.Investment, error) {
	query := `
		SELECT 
			id, org_id, title, category, invested_capital, current_valuation,
			expected_roi, realized_returns, tenure, COALESCE(notes, ''), status,
			investment_date, maturity_date, created_by, created_at, updated_at
		FROM investments
		WHERE id = $1 AND deleted_at IS NULL
	`
	var inv domain.Investment
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&inv.ID, &inv.OrgID, &inv.Title, &inv.Category, &inv.InvestedCapital, &inv.CurrentValuation,
		&inv.ExpectedROI, &inv.RealizedReturns, &inv.Tenure, &inv.Notes, &inv.Status,
		&inv.InvestmentDate, &inv.MaturityDate, &inv.CreatedBy, &inv.CreatedAt, &inv.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch investment: %w", err)
	}
	return &inv, nil
}

func (r *InvestmentRepository) ListByOrg(ctx context.Context, orgID uuid.UUID) ([]domain.Investment, error) {
	query := `
		SELECT 
			id, org_id, title, category, invested_capital, current_valuation,
			expected_roi, realized_returns, tenure, COALESCE(notes, ''), status,
			investment_date, maturity_date, created_by, created_at, updated_at
		FROM investments
		WHERE org_id = $1 AND deleted_at IS NULL
		ORDER BY investment_date DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.Investment
	for rows.Next() {
		var inv domain.Investment
		err := rows.Scan(
			&inv.ID, &inv.OrgID, &inv.Title, &inv.Category, &inv.InvestedCapital, &inv.CurrentValuation,
			&inv.ExpectedROI, &inv.RealizedReturns, &inv.Tenure, &inv.Notes, &inv.Status,
			&inv.InvestmentDate, &inv.MaturityDate, &inv.CreatedBy, &inv.CreatedAt, &inv.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		list = append(list, inv)
	}
	return list, nil
}

func (r *InvestmentRepository) Update(ctx context.Context, inv *domain.Investment) error {
	query := `
		UPDATE investments
		SET title = $2,
		    category = $3,
		    current_valuation = $4,
		    expected_roi = $5,
		    realized_returns = $6,
		    tenure = $7,
		    notes = $8,
		    status = $9,
		    maturity_date = $10,
		    updated_at = NOW()
		WHERE id = $1 AND deleted_at IS NULL
	`
	_, err := r.db.Pool.Exec(ctx, query,
		inv.ID, inv.Title, inv.Category, inv.CurrentValuation, inv.ExpectedROI,
		inv.RealizedReturns, inv.Tenure, inv.Notes, inv.Status, inv.MaturityDate,
	)
	return err
}

func (r *InvestmentRepository) GetPortfolioMetrics(ctx context.Context, orgID uuid.UUID) (*domain.PortfolioMetrics, error) {
	query := `
		SELECT 
			COALESCE(SUM(CASE WHEN status = 'ACTIVE' THEN invested_capital ELSE 0 END), 0.0) as active_capital,
			COALESCE(SUM(CASE WHEN status = 'ACTIVE' THEN current_valuation ELSE 0 END), 0.0) as active_valuation,
			COALESCE(SUM(realized_returns), 0.0) as total_returns,
			COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) as active_count,
			COUNT(CASE WHEN status = 'MATURED' THEN 1 END) as matured_count,
			COUNT(CASE WHEN status = 'LIQUIDATED' THEN 1 END) as liquidated_count
		FROM investments
		WHERE org_id = $1 AND deleted_at IS NULL
	`
	var m domain.PortfolioMetrics
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(
		&m.TotalInvestedCapital,
		&m.TotalCurrentValuation,
		&m.TotalRealizedReturns,
		&m.ActiveInvestmentsCount,
		&m.MaturedInvestmentsCount,
		&m.LiquidatedInvestmentsCount,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch portfolio metrics: %w", err)
	}
	m.UnrealizedGainLoss = m.TotalCurrentValuation - m.TotalInvestedCapital
	return &m, nil
}

func (r *InvestmentRepository) GetTotalActiveCapital(ctx context.Context, orgID uuid.UUID) (float64, error) {
	query := `
		SELECT COALESCE(SUM(invested_capital), 0.0)
		FROM investments
		WHERE org_id = $1 AND status = 'ACTIVE' AND deleted_at IS NULL
	`
	var total float64
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&total)
	return total, err
}

func (r *InvestmentRepository) Delete(ctx context.Context, orgID, id uuid.UUID) error {
	query := `UPDATE investments SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL`
	res, err := r.db.Pool.Exec(ctx, query, id, orgID)
	if err != nil {
		return fmt.Errorf("failed to delete investment: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("investment not found")
	}
	return nil
}
