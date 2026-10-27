package domain

import (
	"time"

	"github.com/google/uuid"
)

type Notification struct {
	ID           uuid.UUID              `json:"id" db:"id"`
	OrgID        *uuid.UUID             `json:"org_id,omitempty" db:"org_id"`
	UserID       uuid.UUID              `json:"user_id" db:"user_id"`
	Title        string                 `json:"title" db:"title"`
	Body         string                 `json:"body" db:"body"`
	Type         string                 `json:"type" db:"type"`
	PayloadJSON  map[string]interface{} `json:"payload,omitempty"`
	IsRead       bool                   `json:"is_read" db:"is_read"`
	FCMMessageID *string                `json:"fcm_message_id,omitempty" db:"fcm_message_id"`
	CreatedAt    time.Time              `json:"created_at" db:"created_at"`
}

type BroadcastNotificationRequest struct {
	Title         string      `json:"title" validate:"required,min=2,max=255"`
	Body          string      `json:"body" validate:"required,min=2"`
	TargetUserIDs []uuid.UUID `json:"target_user_ids,omitempty"`
}

type ScheduleNotificationRequest struct {
	Title         string      `json:"title" validate:"required,min=2,max=255"`
	Body          string      `json:"body" validate:"required,min=2"`
	ScheduledAt   string      `json:"scheduled_at" validate:"required"`
	RepeatRule    string      `json:"repeat_rule" validate:"required,oneof=once daily weekly monthly"`
	TargetUserIDs []uuid.UUID `json:"target_user_ids,omitempty"`
}

type ScheduledNotification struct {
	ID            uuid.UUID   `json:"id"`
	OrgID         uuid.UUID   `json:"org_id"`
	CreatedBy     *uuid.UUID  `json:"created_by,omitempty"`
	Title         string      `json:"title"`
	Body          string      `json:"body"`
	TargetUserIDs []uuid.UUID `json:"target_user_ids"`
	ScheduledAt   time.Time   `json:"scheduled_at"`
	RepeatRule    string      `json:"repeat_rule"`
	LastSentAt    *time.Time  `json:"last_sent_at,omitempty"`
	IsActive      bool        `json:"is_active"`
	CreatedAt     time.Time   `json:"created_at"`
	UpdatedAt     time.Time   `json:"updated_at"`
}
