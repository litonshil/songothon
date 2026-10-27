package postgres

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type ExpenseRepository struct {
	db *DB
}

func NewExpenseRepository(db *DB) *ExpenseRepository {
	return &ExpenseRepository{db: db}
}

func (r *ExpenseRepository) Create(ctx context.Context, e *domain.Expense) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}

	query := `
		INSERT INTO expenses (id, org_id, title, category, amount, expense_date, notes, recorded_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		RETURNING created_at
	`
	err = tx.QueryRow(ctx, query,
		e.ID, e.OrgID, e.Title, e.Category, e.Amount, e.ExpenseDate, e.Notes, e.RecordedBy,
	).Scan(&e.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert expense: %w", err)
	}

	ledgerQuery := `
		INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description, created_at)
		VALUES ($1, $2, 'expense', $3, 'outflow', 'expenses', $4, $5, $6, NOW())
	`
	desc := fmt.Sprintf("Expense: %s", e.Title)
	if _, err := tx.Exec(ctx, ledgerQuery, uuid.New(), e.OrgID, e.Amount, e.ID, e.RecordedBy, desc); err != nil {
		return fmt.Errorf("failed to record expense ledger entry: %w", err)
	}

	return tx.Commit(ctx)
}

func (r *ExpenseRepository) ListByOrg(ctx context.Context, orgID uuid.UUID) ([]domain.Expense, error) {
	query := `
		SELECT id, org_id, title, category, amount, expense_date, COALESCE(notes, ''), recorded_by, created_at
		FROM expenses
		WHERE org_id = $1 AND deleted_at IS NULL
		ORDER BY expense_date DESC, created_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list expenses: %w", err)
	}
	defer rows.Close()

	list := make([]domain.Expense, 0)
	for rows.Next() {
		var e domain.Expense
		if err := rows.Scan(
			&e.ID, &e.OrgID, &e.Title, &e.Category, &e.Amount, &e.ExpenseDate, &e.Notes, &e.RecordedBy, &e.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan expense: %w", err)
		}
		list = append(list, e)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read expenses: %w", err)
	}
	return list, nil
}

func (r *ExpenseRepository) GetTotalExpense(ctx context.Context, orgID uuid.UUID) (float64, error) {
	query := `SELECT COALESCE(SUM(amount), 0.0) FROM expenses WHERE org_id = $1 AND deleted_at IS NULL`
	var total float64
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&total)
	return total, err
}
