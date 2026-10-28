package domain

import (
	"time"

	"github.com/google/uuid"
)

type PeerMemberOverview struct {
	UserID        uuid.UUID `json:"user_id"`
	FullName      string    `json:"full_name"`
	Role          OrgRole   `json:"role"`
	JoinedAt      time.Time `json:"joined_at"`
	SharesCount   *int      `json:"shares_count,omitempty"`   // Omitted if peer visibility false
	TotalSavings  *float64  `json:"total_savings,omitempty"`  // Omitted if peer visibility false
	CurrentStatus *string   `json:"current_status,omitempty"` // Omitted if peer visibility false
}

type MemberDownPaymentStatus struct {
	SchemeID      uuid.UUID `json:"scheme_id"`
	Title         string    `json:"title"`
	Amount        float64   `json:"amount"`
	Frequency     string    `json:"frequency"`
	StartDate     *string   `json:"start_date,omitempty"`
	DueDate       *string   `json:"due_date,omitempty"`
	Status        string    `json:"status"` // Paid, Pending, Unpaid
	PaidAmount    float64   `json:"paid_amount"`
	PendingAmount float64   `json:"pending_amount"`
}

type MemberDashboardData struct {
	OrganizationID                  uuid.UUID                 `json:"organization_id"`
	OrganizationName                string                    `json:"organization_name"`
	OrganizationSlug                string                    `json:"organization_slug"`
	OrganizationDescription         string                    `json:"organization_description,omitempty"`
	Currency                        string                    `json:"currency"`
	AllowPeerListVisibility         bool                      `json:"allow_peer_list_visibility"`
	AllowPeerFinancialVisibility    bool                      `json:"allow_peer_financial_visibility"`
	AllowMemberCollectionVisibility bool                      `json:"allow_member_collection_visibility"`
	CurrentUserRole                 OrgRole                   `json:"current_user_role"`
	PendingApprovalsCount           int                       `json:"pending_approvals_count"`
	ContributionFrequency           string                    `json:"contribution_frequency"`
	DueDayOfPeriod                  int                       `json:"due_day_of_period"`
	PersonalSavings                 float64                   `json:"personal_savings"`
	AssignedShares                  int                       `json:"assigned_shares"`
	BasePricePerShare               float64                   `json:"base_price_per_share"`
	PeriodicFee                     float64                   `json:"periodic_fee"` // Shares * BasePricePerShare
	CurrentCycle                    string                    `json:"current_cycle"`
	CurrentCycleStatus              string                    `json:"current_cycle_status"` // Paid, Pending, Unpaid
	IsCurrentCyclePaid              bool                      `json:"is_current_cycle_paid"`
	TotalOrgDeposits                float64                   `json:"total_org_deposits"`
	TotalExpense                    float64                   `json:"total_expense"`
	TotalIncome                     float64                   `json:"total_income"`
	VaultBalance                    float64                   `json:"vault_balance"`
	InvestedCapital                 float64                   `json:"invested_capital"`
	LiquidityReserve                float64                   `json:"liquidity_reserve"`
	ActiveInvestmentsCount          int                       `json:"active_investments_count"`
	MemberCount                     int                       `json:"member_count"`
	MembersDirectory                []PeerMemberOverview      `json:"members_directory"`
	DownPayments                    []MemberDownPaymentStatus `json:"down_payments"`
}

type MemberCollectionStatus struct {
	UserID         uuid.UUID `json:"user_id"`
	FullName       string    `json:"full_name"`
	SharesCount    int       `json:"shares_count"`
	ExpectedAmount float64   `json:"expected_amount"`
	PaidAmount     float64   `json:"paid_amount"`
	PendingAmount  float64   `json:"pending_amount"`
	Status         string    `json:"status"` // Paid, Pending, Unpaid
}

type AdminDashboardData struct {
	OrganizationID           uuid.UUID                `json:"organization_id"`
	OrganizationName         string                   `json:"organization_name"`
	OrganizationSlug         string                   `json:"organization_slug"`
	Currency                 string                   `json:"currency"`
	TotalDeposits            float64                  `json:"total_deposits"`
	TotalExpense             float64                  `json:"total_expense"`
	TotalIncome              float64                  `json:"total_income"`
	TotalVaultBalance        float64                  `json:"total_vault_balance"`
	TotalInvestedCapital     float64                  `json:"total_invested_capital"`
	AvailableLiquidity       float64                  `json:"available_liquidity"`
	CurrentCycle             string                   `json:"current_cycle"`
	CycleCollectionRate      float64                  `json:"cycle_collection_rate"` // percentage
	TotalExpectedForCycle    float64                  `json:"total_expected_for_cycle"`
	TotalCollectedForCycle   float64                  `json:"total_collected_for_cycle"`
	PendingApprovalsCount    int                      `json:"pending_approvals_count"`
	PendingJoinRequestsCount int                      `json:"pending_join_requests_count"`
	MemberCount              int                      `json:"member_count"`
	PendingDeposits          []ContributionDetail     `json:"pending_deposits"`
	PendingJoinRequests      []PendingJoinRequest     `json:"pending_join_requests"`
	CollectionSummary        []MemberCollectionStatus `json:"collection_summary"`
	PortfolioMetrics         PortfolioMetrics         `json:"portfolio_metrics"`
	Members                  []OrgMemberDetail        `json:"members"`
}
