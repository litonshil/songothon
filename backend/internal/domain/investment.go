package domain

import (
	"time"

	"github.com/google/uuid"
)

type InvestmentStatus string

const (
	InvestmentStatusActive     InvestmentStatus = "active"
	InvestmentStatusMatured    InvestmentStatus = "matured"
	InvestmentStatusLiquidated InvestmentStatus = "liquidated"
	InvestmentStatusLoss       InvestmentStatus = "loss"
)

type Investment struct {
	ID                 uuid.UUID        `json:"id"`
	Name               string           `json:"name"`   // Where we invest (Title)
	AmountInvested     float64          `json:"amount"` // How much amount we invest
	Duration           string           `json:"duration"` // For how long (e.g., "6 Months", "1 Year")
	Sector             string           `json:"sector,omitempty"`
	CurrentValuation   float64          `json:"current_valuation,omitempty"`
	ExpectedReturnRate float64          `json:"expected_return_rate,omitempty"`
	RealizedReturns    float64          `json:"realized_returns,omitempty"`
	Status             InvestmentStatus `json:"status"`
	InvestmentDate     time.Time        `json:"investment_date"`
	MaturityDate       *time.Time       `json:"maturity_date,omitempty"`
	Notes              string           `json:"notes,omitempty"`
	CreatedBy          *uuid.UUID       `json:"created_by,omitempty"`
	CreatorName        string           `json:"creator_name,omitempty"`
	CreatedAt          time.Time        `json:"created_at"`
	UpdatedAt          time.Time        `json:"updated_at"`
}

type CreateInvestmentRequest struct {
	Title          string  `json:"title"`           // Where we invest
	Name           string  `json:"name"`            // Alias for Title
	Amount         float64 `json:"amount"`          // How much we invest
	AmountInvested float64 `json:"amount_invested"` // Alias for Amount
	Duration       string  `json:"duration"`        // For how long we invest
	Sector         string  `json:"sector,omitempty"`
	InvestmentDate string  `json:"investment_date,omitempty"` // YYYY-MM-DD
	Notes          string  `json:"notes,omitempty"`
}

type UpdateInvestmentRequest struct {
	Name     *string           `json:"name,omitempty"`
	Title    *string           `json:"title,omitempty"`
	Amount   *float64          `json:"amount,omitempty"`
	Duration *string           `json:"duration,omitempty"`
	Status   *InvestmentStatus `json:"status,omitempty"`
	Notes    *string           `json:"notes,omitempty"`
}
