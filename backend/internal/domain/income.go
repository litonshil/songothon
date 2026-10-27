package domain

import (
	"time"

	"github.com/google/uuid"
)

type Income struct {
	ID         uuid.UUID  `json:"id" db:"id"`
	OrgID      uuid.UUID  `json:"org_id" db:"org_id"`
	Title      string     `json:"title" db:"title"`
	Category   string     `json:"category" db:"category"`
	Amount     float64    `json:"amount" db:"amount"`
	IncomeDate time.Time  `json:"income_date" db:"income_date"`
	Notes      string     `json:"notes,omitempty" db:"notes"`
	RecordedBy *uuid.UUID `json:"recorded_by,omitempty" db:"recorded_by"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
}

type CreateIncomeRequest struct {
	Title      string  `json:"title"`
	Category   string  `json:"category"`
	Amount     float64 `json:"amount"`
	IncomeDate string  `json:"income_date"` // "YYYY-MM-DD", defaults to today
	Notes      string  `json:"notes,omitempty"`
}
