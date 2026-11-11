package service

import (
	"context"
	"sort"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

func (s *ReportService) ListCycleCollections(
	ctx context.Context,
	org *domain.Organization,
) ([]domain.CycleCollectionSummary, error) {
	basePrice := s.activeBasePrice(ctx, org.ID)
	members, err := s.orgRepo.ListMembers(ctx, org.ID)
	if err != nil {
		return nil, err
	}
	totals, err := s.contribRepo.ListCycleMemberTotals(ctx, org.ID)
	if err != nil {
		return nil, err
	}
	totalsByCycle := groupCycleTotals(totals)

	cycles := cyclesBetween(org.CreatedAt, time.Now())
	result := make([]domain.CycleCollectionSummary, 0, len(cycles))
	for _, cycle := range cycles {
		summary := domain.CycleCollectionSummary{Cycle: cycle}
		for _, m := range membersForCycle(members, cycle, totalsByCycle[cycle]) {
			t := totalsByCycle[cycle][m.UserID]
			summary.ExpectedAmount += float64(m.SharesCount) * basePrice
			summary.CollectedAmount += t.Approved
			summary.PendingAmount += t.Pending
		}
		summary.CollectionRate = collectionRate(summary.CollectedAmount, summary.ExpectedAmount)
		result = append(result, summary)
	}
	return result, nil
}

func (s *ReportService) GetCycleCollection(
	ctx context.Context,
	org *domain.Organization,
	viewer *domain.OrganizationMember,
	cycle string,
) (*domain.CycleCollectionDetail, error) {
	basePrice := s.activeBasePrice(ctx, org.ID)
	members, err := s.orgRepo.ListMembers(ctx, org.ID)
	if err != nil {
		return nil, err
	}
	totals, err := s.contribRepo.ListCycleMemberTotals(ctx, org.ID)
	if err != nil {
		return nil, err
	}
	cycleTotals := groupCycleTotals(totals)[cycle]

	isAdmin := viewer.Role == domain.RoleOrgAdmin
	showList := isAdmin || org.AllowPeerListVisibility
	showFinancial := isAdmin || org.AllowPeerFinancialVisibility

	detail := &domain.CycleCollectionDetail{
		Cycle:   cycle,
		Members: []domain.MemberCycleCollection{},
	}
	for _, m := range membersForCycle(members, cycle, cycleTotals) {
		t := cycleTotals[m.UserID]
		expected := float64(m.SharesCount) * basePrice
		detail.ExpectedAmount += expected
		detail.CollectedAmount += t.Approved
		detail.PendingAmount += t.Pending

		isSelf := m.UserID == viewer.UserID
		if !showList && !isSelf {
			continue
		}
		row := domain.MemberCycleCollection{
			UserID:        m.UserID,
			FullName:      m.FullName,
			IsCurrentUser: isSelf,
			IsSuspended:   m.Status == domain.MemberStatusSuspended,
		}
		if showFinancial || isSelf {
			shares := m.SharesCount
			paid := t.Approved
			pending := t.Pending
			status := domain.CycleStatus(t.Approved, t.Pending, expected)
			row.SharesCount = &shares
			row.ExpectedAmount = &expected
			row.PaidAmount = &paid
			row.PendingAmount = &pending
			row.Status = &status
		}
		detail.Members = append(detail.Members, row)
	}
	sortCollectionRows(detail.Members)
	detail.CollectionRate = collectionRate(detail.CollectedAmount, detail.ExpectedAmount)
	return detail, nil
}

// collectionStatusRank orders rows so the members who still owe come first.
// Rows whose status is hidden from the viewer sort last.
var collectionStatusRank = map[string]int{
	"Unpaid":         0,
	"Partially Paid": 1,
	"Pending":        2,
	"Paid":           3,
}

// sortCollectionRows puts unpaid members at the top, then partially paid,
// pending and paid. Within a group the existing order (role, name) is kept.
func sortCollectionRows(rows []domain.MemberCycleCollection) {
	rank := func(r domain.MemberCycleCollection) int {
		if r.Status != nil {
			if v, ok := collectionStatusRank[*r.Status]; ok {
				return v
			}
		}
		return len(collectionStatusRank)
	}
	sort.SliceStable(rows, func(i, j int) bool { return rank(rows[i]) < rank(rows[j]) })
}

func (s *ReportService) activeBasePrice(ctx context.Context, orgID uuid.UUID) float64 {
	if shareConfig, err := s.orgRepo.GetActiveShareConfig(ctx, orgID); err == nil && shareConfig != nil {
		return shareConfig.BasePricePerShare
	}
	return 0
}

// membersForCycle returns the members counted in a collection cycle: active
// members who had joined by then, plus suspended members who paid (approved
// or pending) in that cycle.
func membersForCycle(
	members []domain.OrgMemberDetail,
	cycle string,
	cycleTotals map[uuid.UUID]domain.CycleMemberTotal,
) []domain.OrgMemberDetail {
	var list []domain.OrgMemberDetail
	for _, m := range members {
		if m.JoinedAt.Local().Format("2006-01") > cycle {
			continue
		}
		switch m.Status {
		case domain.MemberStatusActive:
		case domain.MemberStatusSuspended:
			t := cycleTotals[m.UserID]
			if t.Approved <= 0 && t.Pending <= 0 {
				continue
			}
		default:
			continue
		}
		list = append(list, m)
	}
	return list
}

func groupCycleTotals(totals []domain.CycleMemberTotal) map[string]map[uuid.UUID]domain.CycleMemberTotal {
	grouped := make(map[string]map[uuid.UUID]domain.CycleMemberTotal)
	for _, t := range totals {
		if grouped[t.Cycle] == nil {
			grouped[t.Cycle] = make(map[uuid.UUID]domain.CycleMemberTotal)
		}
		grouped[t.Cycle][t.UserID] = t
	}
	return grouped
}

func cyclesBetween(start, end time.Time) []string {
	s, e := start.Local(), end.Local()
	first := time.Date(s.Year(), s.Month(), 1, 0, 0, 0, 0, time.Local)
	last := time.Date(e.Year(), e.Month(), 1, 0, 0, 0, 0, time.Local)
	var cycles []string
	for c := last; !c.Before(first); c = c.AddDate(0, -1, 0) {
		cycles = append(cycles, c.Format("2006-01"))
	}
	return cycles
}

func collectionRate(collected, expected float64) float64 {
	if expected > 0 {
		return collected / expected * 100.0
	}
	if collected > 0 {
		return 100.0
	}
	return 0
}
