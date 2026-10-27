package postgres

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type NotificationRepository struct {
	db *DB
}

func NewNotificationRepository(db *DB) *NotificationRepository {
	return &NotificationRepository{db: db}
}

func (r *NotificationRepository) Create(ctx context.Context, n *domain.Notification) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	payloadBytes, _ := json.Marshal(n.PayloadJSON)

	query := `
		INSERT INTO notifications (id, org_id, user_id, title, body, type, payload_json, is_read, fcm_message_id, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
		RETURNING created_at
	`
	return r.db.Pool.QueryRow(ctx, query,
		n.ID, n.OrgID, n.UserID, n.Title, n.Body, n.Type, payloadBytes, n.IsRead, n.FCMMessageID,
	).Scan(&n.CreatedAt)
}

func (r *NotificationRepository) ListByUser(ctx context.Context, userID uuid.UUID, limit int) ([]domain.Notification, error) {
	if limit <= 0 {
		limit = 30
	}
	query := `
		SELECT id, org_id, user_id, title, body, type, payload_json, is_read, fcm_message_id, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch notifications: %w", err)
	}
	defer rows.Close()

	var list []domain.Notification
	for rows.Next() {
		var n domain.Notification
		var payloadBytes []byte
		err := rows.Scan(
			&n.ID, &n.OrgID, &n.UserID, &n.Title, &n.Body, &n.Type, &payloadBytes, &n.IsRead, &n.FCMMessageID, &n.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		if len(payloadBytes) > 0 {
			_ = json.Unmarshal(payloadBytes, &n.PayloadJSON)
		}
		list = append(list, n)
	}
	return list, nil
}

func (r *NotificationRepository) MarkAsRead(ctx context.Context, notifID, userID uuid.UUID) error {
	query := `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`
	_, err := r.db.Pool.Exec(ctx, query, notifID, userID)
	return err
}

func (r *NotificationRepository) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Pool.Exec(ctx, `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`, userID)
	return err
}

func (r *NotificationRepository) CreateScheduled(ctx context.Context, n *domain.ScheduledNotification) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	targets, _ := json.Marshal(n.TargetUserIDs)
	query := `
		INSERT INTO scheduled_notifications (id, org_id, created_by, title, body, target_user_ids, scheduled_at, repeat_rule, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, NOW(), NOW())
		RETURNING created_at, updated_at, is_active
	`
	return r.db.Pool.QueryRow(ctx, query,
		n.ID, n.OrgID, n.CreatedBy, n.Title, n.Body, targets, n.ScheduledAt, n.RepeatRule,
	).Scan(&n.CreatedAt, &n.UpdatedAt, &n.IsActive)
}

func (r *NotificationRepository) ListScheduledByOrg(ctx context.Context, orgID uuid.UUID) ([]domain.ScheduledNotification, error) {
	query := `
		SELECT id, org_id, created_by, title, body, target_user_ids, scheduled_at, repeat_rule, last_sent_at, is_active, created_at, updated_at
		FROM scheduled_notifications
		WHERE org_id = $1 AND is_active = true
		ORDER BY scheduled_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list scheduled notifications: %w", err)
	}
	defer rows.Close()

	var list []domain.ScheduledNotification
	for rows.Next() {
		var n domain.ScheduledNotification
		var targets []byte
		if err := rows.Scan(&n.ID, &n.OrgID, &n.CreatedBy, &n.Title, &n.Body, &targets, &n.ScheduledAt, &n.RepeatRule, &n.LastSentAt, &n.IsActive, &n.CreatedAt, &n.UpdatedAt); err != nil {
			return nil, err
		}
		if len(targets) > 0 {
			_ = json.Unmarshal(targets, &n.TargetUserIDs)
		}
		list = append(list, n)
	}
	return list, nil
}

func (r *NotificationRepository) DeleteScheduled(ctx context.Context, orgID, id uuid.UUID) error {
	res, err := r.db.Pool.Exec(ctx, `UPDATE scheduled_notifications SET is_active = false, updated_at = NOW() WHERE id = $1 AND org_id = $2`, id, orgID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("scheduled notification not found")
	}
	return nil
}

func (r *NotificationRepository) DueScheduled(ctx context.Context, limit int) ([]domain.ScheduledNotification, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT id, org_id, created_by, title, body, target_user_ids, scheduled_at, repeat_rule, last_sent_at, is_active, created_at, updated_at
		FROM scheduled_notifications
		WHERE is_active = true AND scheduled_at <= NOW()
		ORDER BY scheduled_at ASC
		LIMIT $1
	`
	rows, err := r.db.Pool.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query due notifications: %w", err)
	}
	defer rows.Close()

	var list []domain.ScheduledNotification
	for rows.Next() {
		var n domain.ScheduledNotification
		var targets []byte
		if err := rows.Scan(&n.ID, &n.OrgID, &n.CreatedBy, &n.Title, &n.Body, &targets, &n.ScheduledAt, &n.RepeatRule, &n.LastSentAt, &n.IsActive, &n.CreatedAt, &n.UpdatedAt); err != nil {
			return nil, err
		}
		if len(targets) > 0 {
			_ = json.Unmarshal(targets, &n.TargetUserIDs)
		}
		list = append(list, n)
	}
	return list, nil
}

func (r *NotificationRepository) AdvanceScheduled(ctx context.Context, id uuid.UUID, next *time.Time) error {
	if next == nil {
		_, err := r.db.Pool.Exec(ctx, `UPDATE scheduled_notifications SET is_active = false, last_sent_at = NOW(), updated_at = NOW() WHERE id = $1`, id)
		return err
	}
	_, err := r.db.Pool.Exec(ctx, `UPDATE scheduled_notifications SET scheduled_at = $2, last_sent_at = NOW(), updated_at = NOW() WHERE id = $1`, id, *next)
	return err
}
