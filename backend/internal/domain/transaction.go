package domain

import (
	"time"

	"github.com/google/uuid"
)

type TransactionType string

const (
	TxDeposit                TransactionType = "deposit"
	TxInvestmentDisbursement TransactionType = "investment_disbursement"
	TxInvestmentDividend     TransactionType = "investment_dividend"
	TxInvestmentLiquidation  TransactionType = "investment_liquidation"
	TxExpense                TransactionType = "expense"
	TxOther                  TransactionType = "other"
)

type FlowType string

const (
	FlowInflow  FlowType = "inflow"
	FlowOutflow FlowType = "outflow"
)

type Transaction struct {
	ID             uuid.UUID       `json:"id"`
	Type           TransactionType `json:"type"`
	Amount         float64         `json:"amount"`
	Flow           FlowType        `json:"flow"`
	ReferenceTable string          `json:"reference_table,omitempty"`
	ReferenceID    *uuid.UUID      `json:"reference_id,omitempty"`
	RecordedBy     *uuid.UUID      `json:"recorded_by,omitempty"`
	Description    string          `json:"description,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
}

type PoolMetrics struct {
	TotalFundsCollected float64 `json:"total_funds_collected"` // Sum of member deposits
	TotalInvested       float64 `json:"total_invested"`        // Sum of active investments
	TotalReturns        float64 `json:"total_returns"`         // Realized returns/dividends
	AvailableLiquidity  float64 `json:"available_liquidity"`   // Collected + Returns - Invested - Expenses
	PortfolioValuation  float64 `json:"portfolio_valuation"`   // Current portfolio market value
	ActiveMembersCount  int     `json:"active_members_count"`  // Count of active users
	InvestmentsCount    int     `json:"investments_count"`     // Count of active investments
}

type FinancialSummaryReport struct {
	Metrics       PoolMetrics    `json:"metrics"`
	RecentLedger  []Transaction  `json:"recent_ledger"`
	TopSectorList []SectorMetric `json:"sector_breakdown"`
}

type SectorMetric struct {
	Sector     string  `json:"sector"`
	TotalAlloc float64 `json:"total_allocated"`
	Percentage float64 `json:"percentage"`
}
