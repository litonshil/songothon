package domain

import (
	"time"

	"github.com/google/uuid"
)

type InvestmentStatus string

const (
	InvestmentStatusActive     InvestmentStatus = "ACTIVE"
	InvestmentStatusMatured    InvestmentStatus = "MATURED"
	InvestmentStatusLiquidated InvestmentStatus = "LIQUIDATED"
)

type Investment struct {
	ID               uuid.UUID        `json:"id" db:"id"`
	OrgID            uuid.UUID        `json:"org_id" db:"org_id"`
	Title            string           `json:"title" db:"title"`
	Category         string           `json:"category" db:"category"`
	InvestedCapital  float64          `json:"invested_capital" db:"invested_capital"`
	CurrentValuation float64          `json:"current_valuation" db:"current_valuation"`
	ExpectedROI      float64          `json:"expected_roi" db:"expected_roi"` // percentage
	RealizedReturns  float64          `json:"realized_returns" db:"realized_returns"`
	Tenure           string           `json:"tenure" db:"tenure"`
	Notes            string           `json:"notes,omitempty" db:"notes"`
	Status           InvestmentStatus `json:"status" db:"status"`
	InvestmentDate   time.Time        `json:"investment_date" db:"investment_date"`
	MaturityDate     *time.Time       `json:"maturity_date,omitempty" db:"maturity_date"`
	CreatedBy        *uuid.UUID       `json:"created_by,omitempty" db:"created_by"`
	CreatedAt        time.Time        `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time        `json:"updated_at" db:"updated_at"`
	DeletedAt        *time.Time       `json:"deleted_at,omitempty" db:"deleted_at"`
}

type CreateInvestmentRequest struct {
	Title            string   `json:"title" validate:"required,min=3,max=200"`
	Category         string   `json:"category" validate:"required"`
	InvestedCapital  float64  `json:"invested_capital" validate:"required,gt=0"`
	CurrentValuation *float64 `json:"current_valuation,omitempty"`
	ExpectedROI      float64  `json:"expected_roi" validate:"gte=0"`
	Tenure           string   `json:"tenure"`
	Notes            string   `json:"notes,omitempty"`
	InvestmentDate   string   `json:"investment_date" validate:"required"` // "YYYY-MM-DD"
	MaturityDate     *string  `json:"maturity_date,omitempty"`             // "YYYY-MM-DD"
}

type UpdateInvestmentRequest struct {
	Title            string            `json:"title,omitempty"`
	Category         string            `json:"category,omitempty"`
	CurrentValuation *float64          `json:"current_valuation,omitempty"`
	ExpectedROI      *float64          `json:"expected_roi,omitempty"`
	RealizedReturns  *float64          `json:"realized_returns,omitempty"`
	Tenure           string            `json:"tenure,omitempty"`
	Notes            string            `json:"notes,omitempty"`
	Status           *InvestmentStatus `json:"status,omitempty" validate:"omitempty,oneof=ACTIVE MATURED LIQUIDATED"`
	MaturityDate     *string           `json:"maturity_date,omitempty"`
}

type PortfolioMetrics struct {
	TotalInvestedCapital       float64 `json:"total_invested_capital"`
	TotalCurrentValuation      float64 `json:"total_current_valuation"`
	TotalRealizedReturns       float64 `json:"total_realized_returns"`
	ActiveInvestmentsCount     int     `json:"active_investments_count"`
	MaturedInvestmentsCount    int     `json:"matured_investments_count"`
	LiquidatedInvestmentsCount int     `json:"liquidated_investments_count"`
	UnrealizedGainLoss         float64 `json:"unrealized_gain_loss"`
}
