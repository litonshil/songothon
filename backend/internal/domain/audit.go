package domain

import (
	"time"

	"github.com/google/uuid"
)

type AuditLog struct {
	ID          uuid.UUID              `json:"id" db:"id"`
	OrgID       *uuid.UUID             `json:"org_id,omitempty" db:"org_id"`
	UserID      *uuid.UUID             `json:"user_id,omitempty" db:"user_id"`
	Action      string                 `json:"action" db:"action"`
	EntityType  string                 `json:"entity_type" db:"entity_type"`
	EntityID    *uuid.UUID             `json:"entity_id,omitempty" db:"entity_id"`
	IPAddress   string                 `json:"ip_address,omitempty" db:"ip_address"`
	DetailsJSON map[string]interface{} `json:"details,omitempty"`
	CreatedAt   time.Time              `json:"created_at" db:"created_at"`
}
