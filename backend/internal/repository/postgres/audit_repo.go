package postgres

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type AuditRepository struct {
	db *DB
}

func NewAuditRepository(db *DB) *AuditRepository {
	return &AuditRepository{db: db}
}

func (r *AuditRepository) Log(ctx context.Context, l *domain.AuditLog) error {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	detailsBytes, _ := json.Marshal(l.DetailsJSON)

	query := `
		INSERT INTO audit_logs (id, org_id, user_id, action, entity_type, entity_id, ip_address, details_json, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		RETURNING created_at
	`
	return r.db.Pool.QueryRow(ctx, query,
		l.ID, l.OrgID, l.UserID, l.Action, l.EntityType, l.EntityID, l.IPAddress, detailsBytes,
	).Scan(&l.CreatedAt)
}

func (r *AuditRepository) ListByOrg(ctx context.Context, orgID uuid.UUID, limit int) ([]domain.AuditLog, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT id, org_id, user_id, action, entity_type, entity_id, COALESCE(ip_address, ''), details_json, created_at
		FROM audit_logs
		WHERE org_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch audit logs: %w", err)
	}
	defer rows.Close()

	var list []domain.AuditLog
	for rows.Next() {
		var a domain.AuditLog
		var detailsBytes []byte
		err := rows.Scan(
			&a.ID, &a.OrgID, &a.UserID, &a.Action, &a.EntityType, &a.EntityID, &a.IPAddress, &detailsBytes, &a.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		if len(detailsBytes) > 0 {
			_ = json.Unmarshal(detailsBytes, &a.DetailsJSON)
		}
		list = append(list, a)
	}
	return list, nil
}
