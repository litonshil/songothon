package postgres

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type IncomeRepository struct {
	db *DB
}

func NewIncomeRepository(db *DB) *IncomeRepository {
	return &IncomeRepository{db: db}
}

func (r *IncomeRepository) Create(ctx context.Context, i *domain.Income) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}

	query := `
		INSERT INTO incomes (id, org_id, title, category, amount, income_date, notes, recorded_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		RETURNING created_at
	`
	err = tx.QueryRow(ctx, query,
		i.ID, i.OrgID, i.Title, i.Category, i.Amount, i.IncomeDate, i.Notes, i.RecordedBy,
	).Scan(&i.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert income: %w", err)
	}

	ledgerQuery := `
		INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description, created_at)
		VALUES ($1, $2, 'income', $3, 'inflow', 'incomes', $4, $5, $6, NOW())
	`
	desc := fmt.Sprintf("Income: %s", i.Title)
	if _, err := tx.Exec(ctx, ledgerQuery, uuid.New(), i.OrgID, i.Amount, i.ID, i.RecordedBy, desc); err != nil {
		return fmt.Errorf("failed to record income ledger entry: %w", err)
	}

	return tx.Commit(ctx)
}

func (r *IncomeRepository) ListByOrg(ctx context.Context, orgID uuid.UUID) ([]domain.Income, error) {
	query := `
		SELECT id, org_id, title, category, amount, income_date, COALESCE(notes, ''), recorded_by, created_at
		FROM incomes
		WHERE org_id = $1 AND deleted_at IS NULL
		ORDER BY income_date DESC, created_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list incomes: %w", err)
	}
	defer rows.Close()

	list := make([]domain.Income, 0)
	for rows.Next() {
		var i domain.Income
		if err := rows.Scan(
			&i.ID, &i.OrgID, &i.Title, &i.Category, &i.Amount, &i.IncomeDate, &i.Notes, &i.RecordedBy, &i.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan income: %w", err)
		}
		list = append(list, i)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read incomes: %w", err)
	}
	return list, nil
}

func (r *IncomeRepository) GetTotalIncome(ctx context.Context, orgID uuid.UUID) (float64, error) {
	query := `SELECT COALESCE(SUM(amount), 0.0) FROM incomes WHERE org_id = $1 AND deleted_at IS NULL`
	var total float64
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&total)
	return total, err
}
