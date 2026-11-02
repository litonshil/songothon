package service

import (
	"context"
	"fmt"
	"log"
	"time"

	"songothon/internal/domain"
)

const (
	downPaymentReminderType   = "down_payment_due"
	downPaymentReminderWindow = 3 // days before the due date
	overdueReminderEvery      = 7 * 24 * time.Hour
)

// SendDownPaymentReminders notifies active members who still owe a mandatory
// scheme's current period: once a day from 3 days before the due date, then
// weekly while overdue. Safe to call repeatedly.
func (s *ContributionService) SendDownPaymentReminders(ctx context.Context, now time.Time) error {
	schemes, err := s.orgRepo.ListAllActiveSchemes(ctx)
	if err != nil {
		return fmt.Errorf("failed to load schemes: %w", err)
	}

	for i := range schemes {
		scheme := &schemes[i]
		if scheme.SchemeType != "mandatory" {
			continue
		}
		period := scheme.PeriodAt(now)
		days := period.DaysUntilDue(now)
		if days > downPaymentReminderWindow {
			continue
		}
		overdue := days < 0
		resendAfter := 20 * time.Hour
		if overdue {
			resendAfter = overdueReminderEvery
		}

		members, err := s.orgRepo.ListMembers(ctx, scheme.OrgID)
		if err != nil {
			log.Printf("[DownPaymentReminders] members for org %s: %v", scheme.OrgID, err)
			continue
		}
		totals, err := s.contribRepo.ListSchemeTotals(ctx, scheme.OrgID, &scheme.ID, nil)
		if err != nil {
			log.Printf("[DownPaymentReminders] totals for scheme %s: %v", scheme.ID, err)
			continue
		}
		idx := indexSchemeTotals(totals)[scheme.ID]

		currency := "BDT"
		if org, _ := s.orgRepo.GetByID(ctx, scheme.OrgID); org != nil && org.Currency != "" {
			currency = org.Currency
		}
		dedupeKey := scheme.ID.String() + ":" + period.Key

		for _, m := range members {
			if m.Status != domain.MemberStatusActive {
				continue
			}
			st := computeStanding(scheme, idx[m.UserID], period, now)
			if st.due <= 0 {
				continue
			}
			if sent, err := s.notifService.SentSince(ctx, m.UserID, downPaymentReminderType, dedupeKey, now.Add(-resendAfter)); err != nil || sent {
				continue
			}

			title := "Down Payment Due ⏳"
			body := fmt.Sprintf("Hi %s, %s %.2f for \"%s\" (%s) is due by %s.",
				m.FullName, currency, st.due, scheme.Title, period.Label, period.DueDate)
			if overdue {
				title = "Down Payment Overdue ⚠️"
				body = fmt.Sprintf("Hi %s, %s %.2f for \"%s\" (%s) was due on %s. Please pay as soon as possible.",
					m.FullName, currency, st.due, scheme.Title, period.Label, period.DueDate)
			}
			_ = s.notifService.SendToUser(ctx, &scheme.OrgID, m.UserID, title, body, downPaymentReminderType, map[string]string{
				"org_id":     scheme.OrgID.String(),
				"scheme_id":  scheme.ID.String(),
				"period":     period.Key,
				"amount_due": fmt.Sprintf("%.2f", st.due),
				"dedupe_key": dedupeKey,
			})
		}
	}
	return nil
}
