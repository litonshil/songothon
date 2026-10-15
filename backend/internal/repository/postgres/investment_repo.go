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

func (r *InvestmentRepository) Create(ctx context.Context, inv *domain.Investment) (*domain.Investment, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	insertInvestmentQuery := `
		INSERT INTO investments (
			name, sector, amount_invested, duration, current_valuation, expected_return_rate,
			realized_returns, status, investment_date, maturity_date, notes, created_by
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, name, sector, amount_invested, COALESCE(duration, ''), current_valuation, expected_return_rate,
		          realized_returns, status, investment_date, maturity_date, notes, created_by,
		          created_at, updated_at
	`
	created := &domain.Investment{}
	err = tx.QueryRow(ctx, insertInvestmentQuery,
		inv.Name,
		inv.Sector,
		inv.AmountInvested,
		inv.Duration,
		inv.CurrentValuation,
		inv.ExpectedReturnRate,
		inv.RealizedReturns,
		inv.Status,
		inv.InvestmentDate,
		inv.MaturityDate,
		inv.Notes,
		inv.CreatedBy,
	).Scan(
		&created.ID,
		&created.Name,
		&created.Sector,
		&created.AmountInvested,
		&created.Duration,
		&created.CurrentValuation,
		&created.ExpectedReturnRate,
		&created.RealizedReturns,
		&created.Status,
		&created.InvestmentDate,
		&created.MaturityDate,
		&created.Notes,
		&created.CreatedBy,
		&created.CreatedAt,
		&created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert investment: %w", err)
	}

	// Ledger outflow record
	insertTxQuery := `
		INSERT INTO transactions (type, amount, flow, reference_table, reference_id, recorded_by, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	desc := fmt.Sprintf("Investment in '%s' (Duration: %s)", inv.Name, inv.Duration)
	_, err = tx.Exec(ctx, insertTxQuery,
		domain.TxInvestmentDisbursement,
		inv.AmountInvested,
		domain.FlowOutflow,
		"investments",
		created.ID,
		inv.CreatedBy,
		desc,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to record disbursement transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit investment transaction: %w", err)
	}

	return created, nil
}

func (r *InvestmentRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.Investment, error) {
	query := `
		SELECT i.id, i.name, i.sector, i.amount_invested, COALESCE(i.duration, ''), i.current_valuation,
		       i.expected_return_rate, i.realized_returns, i.status, i.investment_date,
		       i.maturity_date, COALESCE(i.notes, ''), i.created_by,
		       COALESCE(u.full_name, 'System'), i.created_at, i.updated_at
		FROM investments i
		LEFT JOIN users u ON i.created_by = u.id
		WHERE i.id = $1
	`
	inv := &domain.Investment{}
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&inv.ID,
		&inv.Name,
		&inv.Sector,
		&inv.AmountInvested,
		&inv.Duration,
		&inv.CurrentValuation,
		&inv.ExpectedReturnRate,
		&inv.RealizedReturns,
		&inv.Status,
		&inv.InvestmentDate,
		&inv.MaturityDate,
		&inv.Notes,
		&inv.CreatedBy,
		&inv.CreatorName,
		&inv.CreatedAt,
		&inv.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get investment: %w", err)
	}

	return inv, nil
}

func (r *InvestmentRepository) Update(ctx context.Context, id uuid.UUID, inv *domain.Investment) (*domain.Investment, error) {
	query := `
		UPDATE investments
		SET name = $1, sector = $2, amount_invested = $3, duration = $4,
		    current_valuation = $5, expected_return_rate = $6, realized_returns = $7,
		    status = $8, maturity_date = $9, notes = $10, updated_at = CURRENT_TIMESTAMP
		WHERE id = $11
		RETURNING id, name, sector, amount_invested, COALESCE(duration, ''), current_valuation, expected_return_rate,
		          realized_returns, status, investment_date, maturity_date, notes, created_by,
		          created_at, updated_at
	`
	updated := &domain.Investment{}
	err := r.db.Pool.QueryRow(ctx, query,
		inv.Name,
		inv.Sector,
		inv.AmountInvested,
		inv.Duration,
		inv.CurrentValuation,
		inv.ExpectedReturnRate,
		inv.RealizedReturns,
		inv.Status,
		inv.MaturityDate,
		inv.Notes,
		id,
	).Scan(
		&updated.ID,
		&updated.Name,
		&updated.Sector,
		&updated.AmountInvested,
		&updated.Duration,
		&updated.CurrentValuation,
		&updated.ExpectedReturnRate,
		&updated.RealizedReturns,
		&updated.Status,
		&updated.InvestmentDate,
		&updated.MaturityDate,
		&updated.Notes,
		&updated.CreatedBy,
		&updated.CreatedAt,
		&updated.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update investment: %w", err)
	}

	return updated, nil
}

func (r *InvestmentRepository) List(ctx context.Context, status, sector string) ([]domain.Investment, error) {
	query := `
		SELECT i.id, i.name, i.sector, i.amount_invested, COALESCE(i.duration, ''), i.current_valuation,
		       i.expected_return_rate, i.realized_returns, i.status, i.investment_date,
		       i.maturity_date, COALESCE(i.notes, ''), i.created_by,
		       COALESCE(u.full_name, 'System'), i.created_at, i.updated_at
		FROM investments i
		LEFT JOIN users u ON i.created_by = u.id
		WHERE 1=1
	`
	var args []any
	argIdx := 1

	if status != "" {
		query += fmt.Sprintf(" AND i.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	if sector != "" {
		query += fmt.Sprintf(" AND i.sector = $%d", argIdx)
		args = append(args, sector)
		argIdx++
	}

	query += " ORDER BY i.investment_date DESC"

	rows, err := r.db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query investments: %w", err)
	}
	defer rows.Close()

	var investments []domain.Investment
	for rows.Next() {
		var inv domain.Investment
		if err := rows.Scan(
			&inv.ID,
			&inv.Name,
			&inv.Sector,
			&inv.AmountInvested,
			&inv.Duration,
			&inv.CurrentValuation,
			&inv.ExpectedReturnRate,
			&inv.RealizedReturns,
			&inv.Status,
			&inv.InvestmentDate,
			&inv.MaturityDate,
			&inv.Notes,
			&inv.CreatedBy,
			&inv.CreatorName,
			&inv.CreatedAt,
			&inv.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan investment: %w", err)
		}
		investments = append(investments, inv)
	}

	return investments, nil
}
