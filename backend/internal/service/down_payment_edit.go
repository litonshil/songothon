package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

// Errors returned when an admin edit is not allowed in the scheme's edit mode.
var (
	ErrSchemeLocked        = errors.New("every member has already paid this down payment, so it can no longer be changed")
	ErrSchemeOnlyDates     = errors.New("members have already paid this down payment, so only its start and due dates can be changed")
	ErrSchemeStartAfterPay = errors.New("the start date cannot move past a period members have already paid for")
)

func activeMemberIDs(members []domain.OrgMemberDetail) []uuid.UUID {
	var ids []uuid.UUID
	for _, m := range members {
		if m.Status == domain.MemberStatusActive {
			ids = append(ids, m.UserID)
		}
	}
	return ids
}

// schemeEditMode decides what an admin may still change on a scheme:
//   - full:       no member has paid (approved or pending) anything yet
//   - dates_only: someone has paid, but not every active member has fully
//     paid the current period
//   - locked:     every active member has fully paid the current period
func schemeEditMode(
	scheme *domain.DownPaymentScheme,
	byMember map[uuid.UUID]map[string]periodTotal,
	activeIDs []uuid.UUID,
	now time.Time,
) string {
	if !hasSchemePayments(byMember) {
		return domain.SchemeEditFull
	}
	if len(activeIDs) == 0 {
		return domain.SchemeEditDatesOnly
	}
	period := scheme.PeriodAt(now).Key
	for _, id := range activeIDs {
		if remaining(scheme.Amount, byMember[id][period].approved) > 0 {
			return domain.SchemeEditDatesOnly
		}
	}
	return domain.SchemeEditLocked
}

func hasSchemePayments(byMember map[uuid.UUID]map[string]periodTotal) bool {
	for _, byPeriod := range byMember {
		for _, t := range byPeriod {
			if t.approved > 0 || t.pending > 0 {
				return true
			}
		}
	}
	return false
}

// earliestPaidPeriod returns the smallest period key with a payment, or "".
// Keys of one frequency ("2026-Q1", "2026") sort chronologically as strings.
func earliestPaidPeriod(byMember map[uuid.UUID]map[string]periodTotal) string {
	earliest := ""
	for _, byPeriod := range byMember {
		for key, t := range byPeriod {
			if (t.approved > 0 || t.pending > 0) && (earliest == "" || key < earliest) {
				earliest = key
			}
		}
	}
	return earliest
}

// checkSchemeEdit returns an error if moving from current to updated is not
// allowed in the given edit mode.
func checkSchemeEdit(mode string, current, updated *domain.DownPaymentScheme, byMember map[uuid.UUID]map[string]periodTotal) error {
	switch mode {
	case domain.SchemeEditFull:
		return nil
	case domain.SchemeEditLocked:
		return ErrSchemeLocked
	}

	if updated.Title != current.Title || updated.Amount != current.Amount ||
		updated.SchemeType != current.SchemeType || updated.Frequency != current.Frequency {
		return ErrSchemeOnlyDates
	}
	if updated.Frequency == domain.SchemeFrequencyOneTime {
		return nil
	}
	if earliest := earliestPaidPeriod(byMember); earliest != "" {
		if updated.PeriodKeyFor(updated.SchemeStart()) > earliest {
			return fmt.Errorf("%w (%s)", ErrSchemeStartAfterPay, updated.Period(earliest).Label)
		}
	}
	return nil
}

// UpdateDownPaymentScheme edits a scheme. Every field can change until someone
// pays; after that only the dates can change, and only until every active
// member has fully paid the current period.
func (s *OrgService) UpdateDownPaymentScheme(ctx context.Context, orgID, adminID, schemeID uuid.UUID, req *domain.CreateDownPaymentSchemeRequest) (*domain.DownPaymentScheme, error) {
	current, err := s.orgRepo.GetDownPaymentScheme(ctx, orgID, schemeID)
	if err != nil {
		return nil, err
	}
	if current == nil || !current.IsActive {
		return nil, ErrSchemeNotFound
	}

	updated, err := schemeFromRequest(req)
	if err != nil {
		return nil, err
	}
	updated.ID, updated.OrgID, updated.IsActive, updated.CreatedAt = current.ID, current.OrgID, current.IsActive, current.CreatedAt

	members, err := s.orgRepo.ListMembers(ctx, orgID)
	if err != nil {
		return nil, err
	}
	totals, err := s.contribRepo.ListSchemeTotals(ctx, orgID, &schemeID, nil)
	if err != nil {
		return nil, err
	}
	byMember := indexSchemeTotals(totals)[schemeID]
	now := time.Now()
	mode := schemeEditMode(current, byMember, activeMemberIDs(members), now)
	if err := checkSchemeEdit(mode, current, updated, byMember); err != nil {
		return nil, err
	}

	if err := s.orgRepo.UpdateDownPaymentScheme(ctx, updated); err != nil {
		return nil, fmt.Errorf("failed to update down payment scheme: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "UPDATE_DOWN_PAYMENT_SCHEME",
		EntityType: "down_payment_schemes",
		EntityID:   &schemeID,
		DetailsJSON: map[string]interface{}{
			"before": schemeAuditFields(current),
			"after":  schemeAuditFields(updated),
		},
	})

	schemes := []domain.DownPaymentScheme{*updated}
	decorateSchemes(schemes, now)
	schemes[0].EditMode = schemeEditMode(&schemes[0], byMember, activeMemberIDs(members), now)
	return &schemes[0], nil
}

func schemeAuditFields(s *domain.DownPaymentScheme) map[string]interface{} {
	return map[string]interface{}{
		"title":       s.Title,
		"amount":      s.Amount,
		"scheme_type": s.SchemeType,
		"frequency":   s.Frequency,
		"start_date":  s.StartDate,
		"due_date":    s.DueDate,
	}
}
