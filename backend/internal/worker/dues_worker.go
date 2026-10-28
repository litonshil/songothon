package worker

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"songothon/internal/domain"
	"songothon/internal/service"
)

type DuesWorker struct {
	pool         *pgxpool.Pool
	notifService *service.NotificationService
	interval     time.Duration
}

func NewDuesWorker(pool *pgxpool.Pool, notifService *service.NotificationService, interval time.Duration) *DuesWorker {
	if interval <= 0 {
		interval = 6 * time.Hour
	}
	return &DuesWorker{
		pool:         pool,
		notifService: notifService,
		interval:     interval,
	}
}

func (w *DuesWorker) Start(ctx context.Context) {
	log.Printf("[DuesWorker] Scheduled dues background worker started (interval: %v)\n", w.interval)

	// Run initial checks upon startup in background
	go func() {
		time.Sleep(3 * time.Second)
		if err := w.CheckAndNotifyUpcomingDues(ctx); err != nil {
			log.Printf("[DuesWorker] Initial dues check notice: %v\n", err)
		}
		if err := w.notifService.ProcessScheduled(ctx); err != nil {
			log.Printf("[DuesWorker] Initial scheduled-notification check notice: %v\n", err)
		}
	}()

	duesTicker := time.NewTicker(w.interval)
	scheduleTicker := time.NewTicker(1 * time.Minute)
	go func() {
		defer duesTicker.Stop()
		defer scheduleTicker.Stop()
		for {
			select {
			case <-ctx.Done():
				log.Println("[DuesWorker] Worker stopped gracefully.")
				return
			case <-duesTicker.C:
				if err := w.CheckAndNotifyUpcomingDues(ctx); err != nil {
					log.Printf("[DuesWorker] Error during dues evaluation: %v\n", err)
				}
			case <-scheduleTicker.C:
				if err := w.notifService.ProcessScheduled(ctx); err != nil {
					log.Printf("[DuesWorker] Error during scheduled notification dispatch: %v\n", err)
				}
			}
		}
	}()
}

func (w *DuesWorker) CheckAndNotifyUpcomingDues(ctx context.Context) error {
	now := time.Now()
	currentCycle := now.Format("2006-01")
	todayDay := now.Day()

	// Query all active organizations with their share configuration
	orgQuery := `
		SELECT o.id, o.name, o.currency, sc.base_price_per_share, sc.due_day_of_period
		FROM organizations o
		JOIN share_configurations sc ON sc.org_id = o.id AND sc.is_active = true
		WHERE o.deleted_at IS NULL
	`
	rows, err := w.pool.Query(ctx, orgQuery)
	if err != nil {
		return fmt.Errorf("failed to query active organizations: %w", err)
	}
	defer rows.Close()

	type OrgTarget struct {
		ID        domain.Organization
		BasePrice float64
		DueDay    int
	}

	var targets []OrgTarget
	for rows.Next() {
		var t OrgTarget
		if err := rows.Scan(&t.ID.ID, &t.ID.Name, &t.ID.Currency, &t.BasePrice, &t.DueDay); err != nil {
			continue
		}
		targets = append(targets, t)
	}

	for _, t := range targets {
		// Alert if today is within 3 days before deadline or on deadline
		daysUntilDue := t.DueDay - todayDay
		if daysUntilDue < 0 || daysUntilDue > 3 {
			// Not within 3-day reminder window
			continue
		}

		// Query members whose approved payments for this cycle do not cover their due (unpaid or partially paid)
		memberQuery := `
			SELECT m.user_id, m.shares_count, u.full_name, paid.total
			FROM organization_members m
			JOIN users u ON m.user_id = u.id
			CROSS JOIN LATERAL (
				SELECT COALESCE(SUM(c.amount), 0)::float8 AS total
				FROM contributions c
				WHERE c.org_id = m.org_id AND c.user_id = m.user_id
				  AND c.target_cycle = $2 AND c.status = 'APPROVED' AND c.deleted_at IS NULL
			) paid
			WHERE m.org_id = $1 AND m.status = 'active' AND m.deleted_at IS NULL
			  AND paid.total < m.shares_count * $3::float8
		`
		mRows, err := w.pool.Query(ctx, memberQuery, t.ID.ID, currentCycle, t.BasePrice)
		if err != nil {
			log.Printf("[DuesWorker] Failed to query unpaid members for org %s: %v\n", t.ID.Name, err)
			continue
		}

		for mRows.Next() {
			var userID domain.OrganizationMember
			var shares int
			var fullName string
			var paidAmount float64
			if err := mRows.Scan(&userID.UserID, &shares, &fullName, &paidAmount); err != nil {
				continue
			}

			amountDue := float64(shares)*t.BasePrice - paidAmount
			title := "Upcoming Contribution Due ⏳"
			body := fmt.Sprintf("Hi %s, your installment of %s %.2f for cycle %s is due by day %d.",
				fullName, t.ID.Currency, amountDue, currentCycle, t.DueDay)

			// Send push notification & persist in notifications table
			_ = w.notifService.SendToUser(ctx, &t.ID.ID, userID.UserID, title, body, "dues_alert", map[string]string{
				"org_id":     t.ID.ID.String(),
				"cycle":      currentCycle,
				"amount_due": fmt.Sprintf("%.2f", amountDue),
				"due_day":    fmt.Sprintf("%d", t.DueDay),
			})
		}
		mRows.Close()
	}

	return nil
}
