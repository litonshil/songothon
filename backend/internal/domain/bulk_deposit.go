package domain

import "github.com/google/uuid"

// Bulk deposit upload: an admin uploads an .xlsx sheet whose header row holds an
// "Email" column plus one column per cycle ("2026-01", "2026-02", ...). Each
// non-blank amount cell becomes one approved share_installment contribution.

type BulkDepositItemStatus string

const (
	BulkDepositItemWillCreate BulkDepositItemStatus = "will_create" // dry run: would be inserted
	BulkDepositItemCreated    BulkDepositItemStatus = "created"
	BulkDepositItemDuplicate  BulkDepositItemStatus = "already_recorded" // same member + cycle already imported
)

// BulkDepositCell is one parsed amount cell from the uploaded sheet.
type BulkDepositCell struct {
	Row    int     `json:"row"`
	Email  string  `json:"email"`
	Cycle  string  `json:"cycle"`
	Amount float64 `json:"amount"`
}

type BulkDepositError struct {
	Row     int    `json:"row,omitempty"`
	Column  string `json:"column,omitempty"`
	Message string `json:"message"`
}

type BulkDepositItem struct {
	BulkDepositCell
	UserID         uuid.UUID             `json:"user_id"`
	MemberName     string                `json:"member_name"`
	Status         BulkDepositItemStatus `json:"status"`
	ContributionID *uuid.UUID            `json:"contribution_id,omitempty"`
}

type BulkDepositResult struct {
	DryRun        bool               `json:"dry_run"`
	Imported      bool               `json:"imported"`
	PaymentMethod PaymentMethod      `json:"payment_method"`
	Cycles        []string           `json:"cycles"`
	MemberCount   int                `json:"member_count"`
	CreateCount   int                `json:"create_count"`
	CreateAmount  float64            `json:"create_amount"`
	SkippedCount  int                `json:"skipped_count"`
	SkippedAmount float64            `json:"skipped_amount"`
	Errors        []BulkDepositError `json:"errors"`
	Items         []BulkDepositItem  `json:"items"`
}

// BulkDepositTrxID is deterministic so re-uploading the same sheet never
// double-records a member's deposit for a cycle.
func BulkDepositTrxID(cycle string, userID uuid.UUID) string {
	return "BULK-" + cycle + "-" + userID.String()
}
