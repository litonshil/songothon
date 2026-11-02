package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

// ErrSchemeNotFound is returned when a scheme does not exist in the organization.
var ErrSchemeNotFound = errors.New("down payment scheme not found")

type periodTotal struct{ approved, pending float64 }

// schemeTotals indexes down payment totals as scheme -> member -> period.
type schemeTotals map[uuid.UUID]map[uuid.UUID]map[string]periodTotal

func indexSchemeTotals(list []domain.SchemePaymentTotal) schemeTotals {
	idx := schemeTotals{}
	for _, t := range list {
		if idx[t.SchemeID] == nil {
			idx[t.SchemeID] = map[uuid.UUID]map[string]periodTotal{}
		}
		if idx[t.SchemeID][t.UserID] == nil {
			idx[t.SchemeID][t.UserID] = map[string]periodTotal{}
		}
		idx[t.SchemeID][t.UserID][t.Period] = periodTotal{approved: t.Approved, pending: t.Pending}
	}
	return idx
}

// schemeStanding is a member's position on one scheme for a given period,
// plus what they still owe across every period to date.
type schemeStanding struct {
	period      domain.SchemePeriod
	paid        float64
	pending     float64
	due         float64
	status      string
	overdue     bool
	outstanding float64
	unpaid      []string
}

func computeStanding(scheme *domain.DownPaymentScheme, byPeriod map[string]periodTotal, period domain.SchemePeriod, now time.Time) schemeStanding {
	cur := byPeriod[period.Key]
	st := schemeStanding{
		period:  period,
		paid:    cur.approved,
		pending: cur.pending,
		due:     remaining(scheme.Amount, cur.approved),
		status:  domain.CycleStatus(cur.approved, cur.pending, scheme.Amount),
	}
	st.overdue = st.due > 0 && period.IsPastDue(now)

	for _, p := range scheme.Periods(now) {
		if left := remaining(scheme.Amount, byPeriod[p.Key].approved); left > 0 {
			st.outstanding += left
			st.unpaid = append(st.unpaid, p.Key)
		}
	}
	if st.unpaid == nil {
		st.unpaid = []string{}
	}
	return st
}

func remaining(amount, paid float64) float64 {
	return math.Max(0, math.Round((amount-paid)*100)/100)
}

// decorateSchemes fills in each scheme's billing periods and current period.
func decorateSchemes(schemes []domain.DownPaymentScheme, now time.Time) {
	for i := range schemes {
		s := &schemes[i]
		s.AllPeriods = s.Periods(now)
		cur := s.AllPeriods[len(s.AllPeriods)-1]
		s.CurrentPeriod = &cur
	}
}

func (s *ReportService) buildDownPaymentStatuses(ctx context.Context, orgID, userID uuid.UUID) []domain.MemberDownPaymentStatus {
	schemes, err := s.orgRepo.ListDownPaymentSchemes(ctx, orgID)
	if err != nil || len(schemes) == 0 {
		return []domain.MemberDownPaymentStatus{}
	}
	totals, err := s.contribRepo.ListSchemeTotals(ctx, orgID, nil, &userID)
	if err != nil {
		return []domain.MemberDownPaymentStatus{}
	}
	idx := indexSchemeTotals(totals)

	now := time.Now()
	result := make([]domain.MemberDownPaymentStatus, 0, len(schemes))
	for i := range schemes {
		scheme := &schemes[i]
		st := computeStanding(scheme, idx[scheme.ID][userID], scheme.PeriodAt(now), now)
		result = append(result, domain.MemberDownPaymentStatus{
			SchemeID:          scheme.ID,
			Title:             scheme.Title,
			Amount:            scheme.Amount,
			SchemeType:        scheme.SchemeType,
			Frequency:         scheme.Frequency,
			StartDate:         scheme.StartDate,
			DueDate:           scheme.DueDate,
			CurrentPeriod:     st.period,
			Status:            st.status,
			PaidAmount:        st.paid,
			PendingAmount:     st.pending,
			AmountDue:         st.due,
			IsOverdue:         st.overdue,
			OutstandingAmount: st.outstanding,
			UnpaidPeriods:     st.unpaid,
		})
	}
	return result
}

// GetSchemePeriodReport lists every active member's standing on a scheme for
// one period (the current period when periodKey is empty).
func (s *ReportService) GetSchemePeriodReport(ctx context.Context, orgID, schemeID uuid.UUID, periodKey string) (*domain.SchemePeriodReport, error) {
	scheme, err := s.orgRepo.GetDownPaymentScheme(ctx, orgID, schemeID)
	if err != nil {
		return nil, err
	}
	if scheme == nil {
		return nil, ErrSchemeNotFound
	}

	now := time.Now()
	period := scheme.PeriodAt(now)
	if periodKey != "" {
		if !scheme.ValidPeriodKey(periodKey) {
			return nil, fmt.Errorf("invalid period %q for a %s scheme", periodKey, scheme.Frequency)
		}
		period = scheme.Period(periodKey)
	}

	members, err := s.orgRepo.ListMembers(ctx, orgID)
	if err != nil {
		return nil, err
	}
	totals, err := s.contribRepo.ListSchemeTotals(ctx, orgID, &schemeID, nil)
	if err != nil {
		return nil, err
	}
	idx := indexSchemeTotals(totals)[schemeID]

	decorated := []domain.DownPaymentScheme{*scheme}
	decorateSchemes(decorated, now)
	report := &domain.SchemePeriodReport{
		Scheme:    decorated[0],
		Period:    period,
		IsOverdue: period.IsPastDue(now),
		Members:   []domain.SchemeMemberStatus{},
	}

	for _, m := range members {
		if m.Status != domain.MemberStatusActive {
			continue
		}
		st := computeStanding(scheme, idx[m.UserID], period, now)
		report.ExpectedAmount += scheme.Amount
		report.CollectedAmount += st.paid
		report.PendingAmount += st.pending
		switch st.status {
		case "Paid":
			report.PaidCount++
		case "Partially Paid":
			report.PartialCount++
		default:
			report.UnpaidCount++
		}
		report.Members = append(report.Members, domain.SchemeMemberStatus{
			UserID:            m.UserID,
			FullName:          m.FullName,
			Email:             m.Email,
			PaidAmount:        st.paid,
			PendingAmount:     st.pending,
			AmountDue:         st.due,
			Status:            st.status,
			OutstandingAmount: st.outstanding,
		})
	}

	// Unpaid first, then partial, then paid; alphabetical within each group.
	rank := map[string]int{"Unpaid": 0, "Pending": 1, "Partially Paid": 2, "Paid": 3}
	sort.SliceStable(report.Members, func(i, j int) bool {
		a, b := report.Members[i], report.Members[j]
		if rank[a.Status] != rank[b.Status] {
			return rank[a.Status] < rank[b.Status]
		}
		return a.FullName < b.FullName
	})
	return report, nil
}
