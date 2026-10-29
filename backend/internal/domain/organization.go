package domain

import (
	"time"

	"github.com/google/uuid"
)

type OrgRole string

const (
	RoleOrgAdmin OrgRole = "org_admin"
	RoleMember   OrgRole = "member"
)

type MemberStatus string

const (
	MemberStatusActive    MemberStatus = "active"
	MemberStatusInvited   MemberStatus = "invited"
	MemberStatusPending   MemberStatus = "pending"
	MemberStatusSuspended MemberStatus = "suspended"
	MemberStatusRemoved   MemberStatus = "removed"
)

type ContributionFrequency string

const (
	FrequencyWeekly  ContributionFrequency = "weekly"
	FrequencyMonthly ContributionFrequency = "monthly"
	FrequencyYearly  ContributionFrequency = "yearly"
)

type Organization struct {
	ID                              uuid.UUID  `json:"id" db:"id"`
	Name                            string     `json:"name" db:"name"`
	Slug                            string     `json:"slug" db:"slug"`
	Description                     string     `json:"description" db:"description"`
	Currency                        string     `json:"currency" db:"currency"`
	AllowPeerListVisibility         bool       `json:"allow_peer_list_visibility" db:"allow_peer_list_visibility"`
	AllowPeerFinancialVisibility    bool       `json:"allow_peer_financial_visibility" db:"allow_peer_financial_visibility"`
	AllowMemberCollectionVisibility bool       `json:"allow_member_collection_visibility" db:"allow_member_collection_visibility"`
	CreatedBy                       *uuid.UUID `json:"created_by,omitempty" db:"created_by"`
	CreatedAt                       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt                       time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt                       *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}

type OrganizationMember struct {
	ID          uuid.UUID    `json:"id" db:"id"`
	OrgID       uuid.UUID    `json:"org_id" db:"org_id"`
	UserID      uuid.UUID    `json:"user_id" db:"user_id"`
	Role        OrgRole      `json:"role" db:"role"`
	SharesCount int          `json:"shares_count" db:"shares_count"`
	Status      MemberStatus `json:"status" db:"status"`
	JoinedAt    time.Time    `json:"joined_at" db:"joined_at"`
	CreatedAt   time.Time    `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time    `json:"updated_at" db:"updated_at"`
	DeletedAt   *time.Time   `json:"deleted_at,omitempty" db:"deleted_at"`
}

type OrgMemberDetail struct {
	ID            uuid.UUID    `json:"id"`
	OrgID         uuid.UUID    `json:"org_id"`
	UserID        uuid.UUID    `json:"user_id"`
	FullName      string       `json:"full_name"`
	Email         string       `json:"email"`
	Phone         string       `json:"phone,omitempty"`
	Role          OrgRole      `json:"role"`
	SharesCount   int          `json:"shares_count"`
	Status        MemberStatus `json:"status"`
	JoinedAt      time.Time    `json:"joined_at"`
	TotalSavings  *float64     `json:"total_savings,omitempty"`
	CurrentStatus *string      `json:"current_status,omitempty"`
}

type ShareConfiguration struct {
	ID                uuid.UUID             `json:"id" db:"id"`
	OrgID             uuid.UUID             `json:"org_id" db:"org_id"`
	BasePricePerShare float64               `json:"base_price_per_share" db:"base_price_per_share"`
	Frequency         ContributionFrequency `json:"frequency" db:"frequency"`
	DueDayOfPeriod    int                   `json:"due_day_of_period" db:"due_day_of_period"`
	IsActive          bool                  `json:"is_active" db:"is_active"`
	EffectiveFrom     time.Time             `json:"effective_from" db:"effective_from"`
	CreatedAt         time.Time             `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time             `json:"updated_at" db:"updated_at"`
}

type DownPaymentScheme struct {
	ID         uuid.UUID `json:"id" db:"id"`
	OrgID      uuid.UUID `json:"org_id" db:"org_id"`
	Title      string    `json:"title" db:"title"`
	Amount     float64   `json:"amount" db:"amount"`
	SchemeType string    `json:"scheme_type" db:"scheme_type"` // mandatory, optional
	Frequency  string    `json:"frequency" db:"frequency"`     // one_time, quarterly, yearly
	StartDate  *string   `json:"start_date,omitempty" db:"start_date"`
	DueDate    *string   `json:"due_date,omitempty" db:"due_date"`
	IsActive   bool      `json:"is_active" db:"is_active"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

type OrganizationInvitation struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	OrgID       uuid.UUID  `json:"org_id" db:"org_id"`
	Email       *string    `json:"email,omitempty" db:"email"`
	Phone       *string    `json:"phone,omitempty" db:"phone"`
	Role        OrgRole    `json:"role" db:"role"`
	SharesCount int        `json:"shares_count" db:"shares_count"`
	InvitedBy   *uuid.UUID `json:"invited_by,omitempty" db:"invited_by"`
	Status      string     `json:"status" db:"status"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

type PendingJoinRequest struct {
	MemberID    uuid.UUID `json:"member_id"`
	UserID      uuid.UUID `json:"user_id"`
	FullName    string    `json:"full_name"`
	Email       string    `json:"email"`
	Phone       string    `json:"phone,omitempty"`
	SharesCount int       `json:"shares_count"`
	Status      string    `json:"status"`
	RequestedAt time.Time `json:"requested_at"`
}

// Request & Response DTOs

type CreateOrganizationRequest struct {
	Name                            string                `json:"name" validate:"required,min=2,max=200"`
	Slug                            string                `json:"slug" validate:"required,min=6,max=20"`
	Currency                        string                `json:"currency"`
	Description                     string                `json:"description,omitempty"`
	AllowPeerListVisibility         *bool                 `json:"allow_peer_list_visibility,omitempty"`
	AllowPeerFinancialVisibility    *bool                 `json:"allow_peer_financial_visibility,omitempty"`
	AllowMemberCollectionVisibility *bool                 `json:"allow_member_collection_visibility,omitempty"`
	BasePricePerShare               float64               `json:"base_price_per_share" validate:"required,gt=0"`
	ContributionFrequency           ContributionFrequency `json:"contribution_frequency" validate:"required,oneof=weekly monthly yearly"`
	InitialAdminShares              int                   `json:"initial_admin_shares"`
}

type JoinOrganizationRequest struct {
	Slug string `json:"slug" validate:"required"`
}

type InviteMemberRequest struct {
	EmailOrPhone string  `json:"email_or_phone" validate:"required"`
	Role         OrgRole `json:"role" validate:"required,oneof=org_admin member"`
	SharesCount  int     `json:"shares_count" validate:"gte=0"`
}

type UpdateMemberRequest struct {
	Role        OrgRole      `json:"role,omitempty" validate:"omitempty,oneof=org_admin member"`
	SharesCount *int         `json:"shares_count,omitempty" validate:"omitempty,gte=0"`
	Status      MemberStatus `json:"status,omitempty" validate:"omitempty,oneof=active invited suspended"`
}

type UpdateOrgPrivacyRequest struct {
	AllowPeerListVisibility         *bool `json:"allow_peer_list_visibility,omitempty"`
	AllowPeerFinancialVisibility    *bool `json:"allow_peer_financial_visibility,omitempty"`
	AllowMemberCollectionVisibility *bool `json:"allow_member_collection_visibility,omitempty"`
}

type ConfigureSharesRequest struct {
	BasePricePerShare float64               `json:"base_price_per_share" validate:"required,gt=0"`
	Frequency         ContributionFrequency `json:"frequency" validate:"required,oneof=weekly monthly yearly"`
	DueDayOfPeriod    int                   `json:"due_day_of_period" validate:"required,min=1,max=31"`
}

type CreateDownPaymentSchemeRequest struct {
	Title      string  `json:"title" validate:"required"`
	Amount     float64 `json:"amount" validate:"required,gt=0"`
	SchemeType string  `json:"scheme_type" validate:"required,oneof=mandatory optional"`
	Frequency  string  `json:"frequency" validate:"required,oneof=one_time quarterly yearly"`
	StartDate  *string `json:"start_date,omitempty"`
	DueDate    *string `json:"due_date,omitempty"`
}

type UserOrgMembershipResponse struct {
	Organization Organization `json:"organization"`
	Role         OrgRole      `json:"role"`
	SharesCount  int          `json:"shares_count"`
	Status       MemberStatus `json:"status"`
}
