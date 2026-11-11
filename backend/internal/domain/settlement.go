package domain

import (
	"math"
	"time"

	"github.com/google/uuid"
)

// MemberSettlement is a completed payout to a member leaving the organization.
// The calculated figures are a snapshot taken at settlement time.
type MemberSettlement struct {
	ID               uuid.UUID     `json:"id"`
	OrgID            uuid.UUID     `json:"org_id"`
	UserID           uuid.UUID     `json:"user_id"`
	MemberID         uuid.UUID     `json:"member_id"`
	FullName         string        `json:"full_name,omitempty"`
	Email            string        `json:"email,omitempty"`
	TotalDeposits    float64       `json:"total_deposits"`
	ProfitShare      float64       `json:"profit_share"`
	CalculatedAmount float64       `json:"calculated_amount"`
	Adjustment       float64       `json:"adjustment"`
	FinalAmount      float64       `json:"final_amount"`
	OrgNetProfit     float64       `json:"org_net_profit"`
	StakeDeposits    float64       `json:"stake_deposits"`
	PaymentMethod    PaymentMethod `json:"payment_method"`
	TrxID            string        `json:"trx_id"`
	Notes            string        `json:"notes"`
	SettledBy        *uuid.UUID    `json:"settled_by,omitempty"`
	SettledByName    string        `json:"settled_by_name,omitempty"`
	SettledAt        time.Time     `json:"settled_at"`
}

// SettlementPreview is what an admin sees before confirming a settlement.
type SettlementPreview struct {
	UserID       uuid.UUID    `json:"user_id"`
	FullName     string       `json:"full_name"`
	Email        string       `json:"email"`
	Role         OrgRole      `json:"role"`
	Status       MemberStatus `json:"status"`
	SharesCount  int          `json:"shares_count"`
	Currency     string       `json:"currency"`
	CanSettle    bool         `json:"can_settle"`
	BlockReason  string       `json:"block_reason,omitempty"`
	PendingCount int          `json:"pending_count"`

	// Member side
	TotalDeposits    float64 `json:"total_deposits"`
	OwnershipPercent float64 `json:"ownership_percent"` // member deposits / stake deposits * 100
	ProfitShare      float64 `json:"profit_share"`
	CalculatedAmount float64 `json:"calculated_amount"`

	// Organization side (how the profit was derived)
	TotalIncome         float64 `json:"total_income"`
	TotalExpense        float64 `json:"total_expense"`
	RealizedReturns     float64 `json:"realized_returns"`
	UnrealizedGainLoss  float64 `json:"unrealized_gain_loss"`
	OrgNetProfit        float64 `json:"org_net_profit"`
	ProfitAlreadyPaid   float64 `json:"profit_already_paid"` // profit share paid in earlier settlements
	DistributableProfit float64 `json:"distributable_profit"`
	StakeDeposits       float64 `json:"stake_deposits"`
	AvailableCash       float64 `json:"available_cash"`
}

type SettleMemberRequest struct {
	// FinalAmount defaults to the calculated amount when omitted.
	FinalAmount   *float64      `json:"final_amount,omitempty"`
	PaymentMethod PaymentMethod `json:"payment_method"`
	TrxID         string        `json:"trx_id"`
	Notes         string        `json:"notes"`
}

// SettlementInputs are the figures a settlement calculation is based on.
type SettlementInputs struct {
	MemberDeposits    float64 // member's approved deposits not yet settled
	StakeDeposits     float64 // all current stakeholders' unsettled deposits (member included)
	NetProfit         float64 // income - expense + realized returns + unrealized gain/loss
	ProfitAlreadyPaid float64 // sum of profit_share over earlier settlements
}

type SettlementResult struct {
	OwnershipPercent    float64
	DistributableProfit float64
	ProfitShare         float64
	CalculatedAmount    float64
}

// CalculateSettlement splits the not-yet-distributed profit (or loss) by each
// stakeholder's share of the deposits and adds the member's part to their
// deposits. The payout never goes below zero.
func CalculateSettlement(in SettlementInputs) SettlementResult {
	distributable := RoundMoney(in.NetProfit - in.ProfitAlreadyPaid)
	res := SettlementResult{DistributableProfit: distributable}
	if in.MemberDeposits <= 0 || in.StakeDeposits <= 0 {
		res.CalculatedAmount = math.Max(0, RoundMoney(in.MemberDeposits))
		return res
	}
	ratio := in.MemberDeposits / in.StakeDeposits
	if ratio > 1 {
		ratio = 1
	}
	res.OwnershipPercent = math.Round(ratio*10000) / 100
	res.ProfitShare = RoundMoney(distributable * ratio)
	res.CalculatedAmount = math.Max(0, RoundMoney(in.MemberDeposits+res.ProfitShare))
	return res
}

// RoundMoney rounds to two decimal places.
func RoundMoney(v float64) float64 {
	return math.Round(v*100) / 100
}
