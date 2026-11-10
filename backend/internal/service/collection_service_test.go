package service

import (
	"reflect"
	"testing"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

func TestCyclesBetweenLatestFirst(t *testing.T) {
	start := time.Date(2026, time.August, 20, 10, 0, 0, 0, time.Local)
	end := time.Date(2026, time.October, 3, 9, 0, 0, 0, time.Local)

	got := cyclesBetween(start, end)
	want := []string{"2026-10", "2026-09", "2026-08"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("cyclesBetween() = %v, want %v", got, want)
	}
}

func TestCyclesBetweenSameMonth(t *testing.T) {
	now := time.Date(2026, time.October, 28, 0, 0, 0, 0, time.Local)

	got := cyclesBetween(now, now)
	want := []string{"2026-10"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("cyclesBetween() = %v, want %v", got, want)
	}
}

func TestCollectionRate(t *testing.T) {
	tests := []struct {
		name      string
		collected float64
		expected  float64
		want      float64
	}{
		{"half collected", 500, 1000, 50},
		{"nothing expected, nothing collected", 0, 0, 0},
		{"nothing expected, something collected", 200, 0, 100},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := collectionRate(tt.collected, tt.expected); got != tt.want {
				t.Errorf("collectionRate(%v, %v) = %v, want %v", tt.collected, tt.expected, got, tt.want)
			}
		})
	}
}

func TestMembersForCycleSuspended(t *testing.T) {
	joined := time.Date(2026, time.January, 5, 0, 0, 0, 0, time.Local)
	active := domain.OrgMemberDetail{UserID: uuid.New(), Status: domain.MemberStatusActive, JoinedAt: joined}
	suspended := domain.OrgMemberDetail{UserID: uuid.New(), Status: domain.MemberStatusSuspended, JoinedAt: joined}
	removed := domain.OrgMemberDetail{UserID: uuid.New(), Status: domain.MemberStatusRemoved, JoinedAt: joined}
	members := []domain.OrgMemberDetail{active, suspended, removed}

	ids := func(list []domain.OrgMemberDetail) []uuid.UUID {
		var out []uuid.UUID
		for _, m := range list {
			out = append(out, m.UserID)
		}
		return out
	}

	tests := []struct {
		name   string
		cycle  string
		totals map[uuid.UUID]domain.CycleMemberTotal
		want   []uuid.UUID
	}{
		{"suspended, unpaid", "2026-03", nil, []uuid.UUID{active.UserID}},
		{"suspended, approved payment", "2026-03", map[uuid.UUID]domain.CycleMemberTotal{suspended.UserID: {Approved: 500}}, []uuid.UUID{active.UserID, suspended.UserID}},
		{"suspended, pending payment", "2026-03", map[uuid.UUID]domain.CycleMemberTotal{suspended.UserID: {Pending: 100}}, []uuid.UUID{active.UserID, suspended.UserID}},
		{"removed, paid", "2026-03", map[uuid.UUID]domain.CycleMemberTotal{removed.UserID: {Approved: 500}}, []uuid.UUID{active.UserID}},
		{"before join", "2025-12", map[uuid.UUID]domain.CycleMemberTotal{suspended.UserID: {Approved: 500}}, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ids(membersForCycle(members, tt.cycle, tt.totals))
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("membersForCycle(%s) = %v, want %v", tt.cycle, got, tt.want)
			}
		})
	}
}
