package service

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
	"songothon/pkg/fcm"
)

type NotificationService struct {
	notifRepo *postgres.NotificationRepository
	userRepo  *postgres.UserRepository
	orgRepo   *postgres.OrgRepository
	fcmClient fcm.Client
}

func NewNotificationService(
	notifRepo *postgres.NotificationRepository,
	userRepo *postgres.UserRepository,
	orgRepo *postgres.OrgRepository,
	fcmClient fcm.Client,
) *NotificationService {
	return &NotificationService{
		notifRepo: notifRepo,
		userRepo:  userRepo,
		orgRepo:   orgRepo,
		fcmClient: fcmClient,
	}
}

func (s *NotificationService) SendToUser(
	ctx context.Context,
	orgID *uuid.UUID,
	userID uuid.UUID,
	title string,
	body string,
	notifType string,
	data map[string]string,
) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil || user == nil {
		return fmt.Errorf("recipient user not found: %w", err)
	}

	var fcmMsgID *string
	if user.FCMToken != "" && s.fcmClient != nil {
		msgID, pushErr := s.fcmClient.SendPush(ctx, user.FCMToken, title, body, data)
		if pushErr != nil {
			log.Printf("[NotificationService] Warning: push notification delivery failed: %v\n", pushErr)
		} else {
			fcmMsgID = &msgID
		}
	}

	payload := make(map[string]interface{})
	for k, v := range data {
		payload[k] = v
	}

	notif := &domain.Notification{
		ID:           uuid.New(),
		OrgID:        orgID,
		UserID:       userID,
		Title:        title,
		Body:         body,
		Type:         notifType,
		PayloadJSON:  payload,
		IsRead:       false,
		FCMMessageID: fcmMsgID,
	}

	return s.notifRepo.Create(ctx, notif)
}

func (s *NotificationService) SendToMembers(ctx context.Context, orgID uuid.UUID, userIDs []uuid.UUID, title, body string) error {
	if len(userIDs) == 0 {
		members, err := s.orgRepo.ListMembers(ctx, orgID)
		if err != nil {
			return fmt.Errorf("failed to list organization members: %w", err)
		}
		for _, member := range members {
			if member.Status != domain.MemberStatusActive {
				continue
			}
			_ = s.SendToUser(ctx, &orgID, member.UserID, title, body, "broadcast", map[string]string{
				"org_id": orgID.String(),
				"type":   "broadcast",
			})
		}
		return nil
	}

	// Selected recipients must be active members of this tenant. This prevents
	// an admin from targeting users in other organizations by guessing IDs.
	members, err := s.orgRepo.ListMembers(ctx, orgID)
	if err != nil {
		return fmt.Errorf("failed to list organization members: %w", err)
	}
	active := make(map[uuid.UUID]bool, len(members))
	for _, member := range members {
		if member.Status == domain.MemberStatusActive {
			active[member.UserID] = true
		}
	}
	for _, userID := range userIDs {
		if !active[userID] {
			continue
		}
		_ = s.SendToUser(ctx, &orgID, userID, title, body, "broadcast", map[string]string{
			"org_id": orgID.String(),
			"type":   "broadcast",
		})
	}
	return nil
}

func (s *NotificationService) BroadcastToOrg(ctx context.Context, orgID uuid.UUID, title string, body string) error {
	return s.SendToMembers(ctx, orgID, nil, title, body)
}

func (s *NotificationService) Schedule(ctx context.Context, orgID, adminID uuid.UUID, req *domain.ScheduleNotificationRequest) (*domain.ScheduledNotification, error) {
	scheduledAt, err := time.Parse(time.RFC3339, req.ScheduledAt)
	if err != nil {
		scheduledAt, err = time.Parse("2006-01-02T15:04", req.ScheduledAt)
	}
	if err != nil {
		return nil, fmt.Errorf("scheduled_at must be an ISO-8601 date-time")
	}
	if scheduledAt.Before(time.Now().Add(-time.Minute)) {
		return nil, fmt.Errorf("scheduled time must be in the future")
	}
	rule := req.RepeatRule
	if rule == "" {
		rule = "once"
	}
	n := &domain.ScheduledNotification{
		OrgID:         orgID,
		CreatedBy:     &adminID,
		Title:         req.Title,
		Body:          req.Body,
		TargetUserIDs: req.TargetUserIDs,
		ScheduledAt:   scheduledAt,
		RepeatRule:    rule,
	}
	if err := s.notifRepo.CreateScheduled(ctx, n); err != nil {
		return nil, err
	}
	return n, nil
}

func (s *NotificationService) ListScheduled(ctx context.Context, orgID uuid.UUID) ([]domain.ScheduledNotification, error) {
	return s.notifRepo.ListScheduledByOrg(ctx, orgID)
}

func (s *NotificationService) DeleteScheduled(ctx context.Context, orgID, id uuid.UUID) error {
	return s.notifRepo.DeleteScheduled(ctx, orgID, id)
}

// ProcessScheduled sends every due scheduled/repeating notification and advances
// its next run time according to the repeat rule.
func (s *NotificationService) ProcessScheduled(ctx context.Context) error {
	due, err := s.notifRepo.DueScheduled(ctx, 50)
	if err != nil {
		return err
	}
	for _, n := range due {
		if err := s.SendToMembers(ctx, n.OrgID, n.TargetUserIDs, n.Title, n.Body); err != nil {
			log.Printf("[NotificationService] Failed to send scheduled notification %s: %v\n", n.ID, err)
			continue
		}
		var next *time.Time
		switch n.RepeatRule {
		case "daily":
			t := n.ScheduledAt.AddDate(0, 0, 1)
			next = &t
		case "weekly":
			t := n.ScheduledAt.AddDate(0, 0, 7)
			next = &t
		case "monthly":
			t := n.ScheduledAt.AddDate(0, 1, 0)
			next = &t
		}
		if next != nil {
			for next.Before(time.Now()) {
				switch n.RepeatRule {
				case "daily":
					*next = next.AddDate(0, 0, 1)
				case "weekly":
					*next = next.AddDate(0, 0, 7)
				case "monthly":
					*next = next.AddDate(0, 1, 0)
				}
			}
		}
		_ = s.notifRepo.AdvanceScheduled(ctx, n.ID, next)
	}
	return nil
}

func (s *NotificationService) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	return s.notifRepo.MarkAllAsRead(ctx, userID)
}

func (s *NotificationService) ListUserNotifications(ctx context.Context, userID uuid.UUID, limit int) ([]domain.Notification, error) {
	return s.notifRepo.ListByUser(ctx, userID, limit)
}

func (s *NotificationService) MarkAsRead(ctx context.Context, notifID, userID uuid.UUID) error {
	return s.notifRepo.MarkAsRead(ctx, notifID, userID)
}
