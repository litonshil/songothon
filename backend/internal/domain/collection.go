package domain

import (
	"github.com/google/uuid"
)

type CycleMemberTotal struct {
	Cycle    string    `json:"cycle"`
	UserID   uuid.UUID `json:"user_id"`
	Approved float64   `json:"approved"`
	Pending  float64   `json:"pending"`
}

type CycleCollectionSummary struct {
	Cycle           string  `json:"cycle"`
	ExpectedAmount  float64 `json:"expected_amount"`
	CollectedAmount float64 `json:"collected_amount"`
	PendingAmount   float64 `json:"pending_amount"`
	CollectionRate  float64 `json:"collection_rate"`
}

type MemberCycleCollection struct {
	UserID         uuid.UUID `json:"user_id"`
	FullName       string    `json:"full_name"`
	IsCurrentUser  bool      `json:"is_current_user"`
	SharesCount    *int      `json:"shares_count,omitempty"`    // Omitted if financial visibility hidden
	ExpectedAmount *float64  `json:"expected_amount,omitempty"` // Omitted if financial visibility hidden
	PaidAmount     *float64  `json:"paid_amount,omitempty"`     // Omitted if financial visibility hidden
	PendingAmount  *float64  `json:"pending_amount,omitempty"`  // Omitted if financial visibility hidden
	Status         *string   `json:"status,omitempty"`          // Omitted if financial visibility hidden
}

type CycleCollectionDetail struct {
	Cycle           string                  `json:"cycle"`
	ExpectedAmount  float64                 `json:"expected_amount"`
	CollectedAmount float64                 `json:"collected_amount"`
	PendingAmount   float64                 `json:"pending_amount"`
	CollectionRate  float64                 `json:"collection_rate"`
	Members         []MemberCycleCollection `json:"members"`
}
