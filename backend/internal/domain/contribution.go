package domain

import (
	"time"

	"github.com/google/uuid"
)

type PeriodFrequency string

const (
	FrequencyWeekly    PeriodFrequency = "weekly"
	FrequencyMonthly   PeriodFrequency = "monthly"
	FrequencyQuarterly PeriodFrequency = "quarterly"
	FrequencyAdHoc     PeriodFrequency = "ad_hoc"
)

type ContributionPeriod struct {
	ID        uuid.UUID       `json:"id"`
	Title     string          `json:"title"`
	Frequency PeriodFrequency `json:"frequency"`
	AmountDue float64         `json:"amount_due"`
	DueDate   time.Time       `json:"due_date"`
	IsActive  bool            `json:"is_active"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

type CreatePeriodRequest struct {
	Title     string          `json:"title" validate:"required"`
	Frequency PeriodFrequency `json:"frequency" validate:"required,oneof=weekly monthly quarterly ad_hoc"`
	AmountDue float64         `json:"amount_due" validate:"required,gt=0"`
	DueDate   string          `json:"due_date" validate:"required"` // Format: YYYY-MM-DD
}

type ContributionStatus string

const (
	ContributionPaid     ContributionStatus = "paid"
	ContributionPending  ContributionStatus = "pending"
	ContributionWaived   ContributionStatus = "waived"
	ContributionRejected ContributionStatus = "rejected"
)

type Contribution struct {
	ID            uuid.UUID          `json:"id"`
	UserID        uuid.UUID          `json:"user_id"`
	MemberName    string             `json:"member_name,omitempty"`
	MemberEmail   string             `json:"member_email,omitempty"`
	PeriodID      *uuid.UUID         `json:"period_id,omitempty"`
	PeriodTitle   string             `json:"period_title,omitempty"`
	Amount        float64            `json:"amount"`
	PaymentMethod string             `json:"payment_method"`
	ReferenceNo   string             `json:"transaction_id"` // Transaction ID / Ref
	Status        ContributionStatus `json:"status"`         // "pending" -> "paid"
	RecordedBy    *uuid.UUID         `json:"recorded_by,omitempty"`
	RecorderName  string             `json:"recorder_name,omitempty"`
	PaidAt        time.Time          `json:"paid_at"`
	Notes         string             `json:"notes,omitempty"`
	CreatedAt     time.Time          `json:"created_at"`
	UpdatedAt     time.Time          `json:"updated_at"`
}

// SubmitDepositRequest is used by members to submit their monthly deposit
type SubmitDepositRequest struct {
	PeriodID      *uuid.UUID `json:"period_id"`
	Amount        float64    `json:"amount"` // Predefined by period if <= 0
	PaymentMethod string     `json:"payment_method" validate:"required"` // bkash, nagad, bank, cash
	TransactionID string     `json:"transaction_id" validate:"required"` // TrxID from bKash/Nagad/Bank
	Notes         string     `json:"notes,omitempty"`
}

// RecordDepositRequest is used by admin to directly record a verified deposit
type RecordDepositRequest struct {
	UserID        uuid.UUID  `json:"user_id" validate:"required"`
	PeriodID      *uuid.UUID `json:"period_id,omitempty"`
	Amount        float64    `json:"amount" validate:"required,gt=0"`
	PaymentMethod string     `json:"payment_method" validate:"required"`
	TransactionID string     `json:"transaction_id,omitempty"`
	ReferenceNo   string     `json:"reference_no,omitempty"`
	Notes         string     `json:"notes,omitempty"`
	PaidAt        string     `json:"paid_at,omitempty"`
}

type MemberFinancialSummary struct {
	UserID            uuid.UUID      `json:"user_id"`
	FullName          string         `json:"full_name"`
	Email             string         `json:"email"`
	TotalContributed  float64        `json:"total_contributed"`
	PendingDues       float64        `json:"pending_dues"`
	TotalCycles       int            `json:"total_cycles"`
	PaidCycles        int            `json:"paid_cycles"`
	PendingCycles     int            `json:"pending_cycles"`
	ContributionsList []Contribution `json:"recent_contributions,omitempty"`
}

type MonthlyDepositReport struct {
	PeriodID       uuid.UUID      `json:"period_id"`
	PeriodTitle    string         `json:"period_title"`
	AmountDue      float64        `json:"amount_due"`
	DueDate        time.Time      `json:"due_date"`
	TotalCollected float64        `json:"total_collected"`
	TotalPending   float64        `json:"total_pending"`
	PaidCount      int            `json:"paid_count"`
	PendingCount   int            `json:"pending_count"`
	Deposits       []Contribution `json:"deposits"`
}
