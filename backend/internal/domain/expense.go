package domain

import (
	"time"

	"github.com/google/uuid"
)

type Expense struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	OrgID       uuid.UUID  `json:"org_id" db:"org_id"`
	Title       string     `json:"title" db:"title"`
	Category    string     `json:"category" db:"category"`
	Amount      float64    `json:"amount" db:"amount"`
	ExpenseDate time.Time  `json:"expense_date" db:"expense_date"`
	Notes       string     `json:"notes,omitempty" db:"notes"`
	RecordedBy  *uuid.UUID `json:"recorded_by,omitempty" db:"recorded_by"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
}

type CreateExpenseRequest struct {
	Title       string  `json:"title"`
	Category    string  `json:"category"`
	Amount      float64 `json:"amount"`
	ExpenseDate string  `json:"expense_date"` // "YYYY-MM-DD", defaults to today
	Notes       string  `json:"notes,omitempty"`
}
