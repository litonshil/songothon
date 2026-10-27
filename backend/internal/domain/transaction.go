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
	ID             uuid.UUID       `json:"id" db:"id"`
	OrgID          uuid.UUID       `json:"org_id" db:"org_id"`
	Type           TransactionType `json:"type" db:"type"`
	Amount         float64         `json:"amount" db:"amount"`
	Flow           FlowType        `json:"flow" db:"flow"`
	ReferenceTable string          `json:"reference_table,omitempty" db:"reference_table"`
	ReferenceID    *uuid.UUID      `json:"reference_id,omitempty" db:"reference_id"`
	RecordedBy     *uuid.UUID      `json:"recorded_by,omitempty" db:"recorded_by"`
	Description    string          `json:"description,omitempty" db:"description"`
	CreatedAt      time.Time       `json:"created_at" db:"created_at"`
}
