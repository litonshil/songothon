package domain

import (
	"time"

	"github.com/google/uuid"
)

type ContributionStatus string

const (
	ContributionStatusPending  ContributionStatus = "PENDING"
	ContributionStatusApproved ContributionStatus = "APPROVED"
	ContributionStatusRejected ContributionStatus = "REJECTED"
)

type ContributionType string

const (
	ContributionTypeShareInstallment ContributionType = "share_installment"
	ContributionTypeDownPayment      ContributionType = "down_payment"
	ContributionTypeAdHoc            ContributionType = "ad_hoc"
)

type PaymentMethod string

const (
	PaymentMethodBKash        PaymentMethod = "bkash"
	PaymentMethodNagad        PaymentMethod = "nagad"
	PaymentMethodRocket       PaymentMethod = "rocket"
	PaymentMethodBankTransfer PaymentMethod = "bank_transfer"
	PaymentMethodCash         PaymentMethod = "cash"
)

type Contribution struct {
	ID              uuid.UUID          `json:"id" db:"id"`
	OrgID           uuid.UUID          `json:"org_id" db:"org_id"`
	UserID          uuid.UUID          `json:"user_id" db:"user_id"`
	Type            ContributionType   `json:"type" db:"type"`
	Amount          float64            `json:"amount" db:"amount"`
	PaymentMethod   PaymentMethod      `json:"payment_method" db:"payment_method"`
	TrxID           string             `json:"trx_id" db:"trx_id"`
	SenderAccount   string             `json:"sender_account" db:"sender_account"`
	ReceiptURL      string             `json:"receipt_url,omitempty" db:"receipt_url"`
	TargetCycle     string             `json:"target_cycle" db:"target_cycle"`
	Status          ContributionStatus `json:"status" db:"status"`
	RejectionReason *string            `json:"rejection_reason,omitempty" db:"rejection_reason"`
	ReviewedBy      *uuid.UUID         `json:"reviewed_by,omitempty" db:"reviewed_by"`
	ReviewedAt      *time.Time         `json:"reviewed_at,omitempty" db:"reviewed_at"`
	PaidAt          time.Time          `json:"paid_at" db:"paid_at"`
	Notes           string             `json:"notes,omitempty" db:"notes"`
	CreatedAt       time.Time          `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time          `json:"updated_at" db:"updated_at"`
	DeletedAt       *time.Time         `json:"deleted_at,omitempty" db:"deleted_at"`
}

type ContributionDetail struct {
	Contribution
	MemberName  string `json:"member_name"`
	MemberEmail string `json:"member_email"`
	MemberPhone string `json:"member_phone,omitempty"`
}

// DTOs

type SubmitDepositRequest struct {
	Type          ContributionType `json:"type" validate:"required,oneof=share_installment down_payment ad_hoc"`
	Amount        float64          `json:"amount" validate:"required,gt=0"`
	PaymentMethod PaymentMethod    `json:"payment_method" validate:"required,oneof=bkash nagad rocket bank_transfer cash"`
	TrxID         string           `json:"trx_id" validate:"required,min=4,max=100"`
	SenderAccount string           `json:"sender_account" validate:"required,min=4,max=100"`
	ReceiptURL    string           `json:"receipt_url,omitempty"`
	TargetCycle   string           `json:"target_cycle" validate:"required"` // e.g. "2026-10" or "Q4-2026"
	Notes         string           `json:"notes,omitempty"`
	// UserID lets an organization admin submit a deposit on behalf of another member.
	// It is ignored when omitted or equal to the authenticated user.
	UserID *uuid.UUID `json:"user_id,omitempty"`
}

type ReviewDepositRequest struct {
	Status          ContributionStatus `json:"status" validate:"required,oneof=APPROVED REJECTED"`
	RejectionReason string             `json:"rejection_reason,omitempty"`
}

type MemberDuesSummary struct {
	UserID             uuid.UUID `json:"user_id"`
	FullName           string    `json:"full_name"`
	SharesCount        int       `json:"shares_count"`
	BasePricePerShare  float64   `json:"base_price_per_share"`
	PeriodicFee        float64   `json:"periodic_fee"` // SharesCount * BasePricePerShare
	CurrentCycle       string    `json:"current_cycle"`
	IsCyclePaid        bool      `json:"is_cycle_paid"`
	CumulativeDeposits float64   `json:"cumulative_deposits"`
}

func CycleStatus(approved, pending, expected float64) string {
	switch {
	case approved > 0 && (expected <= 0 || approved >= expected):
		return "Paid"
	case approved > 0:
		return "Partially Paid"
	case pending > 0:
		return "Pending"
	default:
		return "Unpaid"
	}
}
