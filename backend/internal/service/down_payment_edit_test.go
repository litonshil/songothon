package service

import (
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

func strPtr(s string) *string { return &s }

func TestSchemeEditMode(t *testing.T) {
	now := time.Date(2026, time.November, 11, 0, 0, 0, 0, time.UTC)
	scheme := &domain.DownPaymentScheme{Amount: 1000, Frequency: domain.SchemeFrequencyOneTime, StartDate: strPtr("2026-11-01")}
	a, b, gone := uuid.New(), uuid.New(), uuid.New()
	active := []uuid.UUID{a, b}

	tests := []struct {
		name     string
		byMember map[uuid.UUID]map[string]periodTotal
		want     string
	}{
		{"nobody paid", nil, domain.SchemeEditFull},
		{"one pending", map[uuid.UUID]map[string]periodTotal{a: {"once": {pending: 1000}}}, domain.SchemeEditDatesOnly},
		{"one paid", map[uuid.UUID]map[string]periodTotal{a: {"once": {approved: 1000}}}, domain.SchemeEditDatesOnly},
		{"all paid, one partially", map[uuid.UUID]map[string]periodTotal{a: {"once": {approved: 1000}}, b: {"once": {approved: 400}}}, domain.SchemeEditDatesOnly},
		{"all paid", map[uuid.UUID]map[string]periodTotal{a: {"once": {approved: 1000}}, b: {"once": {approved: 1000}}}, domain.SchemeEditLocked},
		{"only a former member paid", map[uuid.UUID]map[string]periodTotal{gone: {"once": {approved: 1000}}}, domain.SchemeEditDatesOnly},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := schemeEditMode(scheme, tt.byMember, active, now); got != tt.want {
				t.Errorf("schemeEditMode() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestCheckSchemeEdit(t *testing.T) {
	quarterly := func(start, due string) *domain.DownPaymentScheme {
		s := &domain.DownPaymentScheme{Title: "Land", Amount: 1000, SchemeType: "mandatory", Frequency: domain.SchemeFrequencyQuarterly, StartDate: strPtr(start)}
		if due != "" {
			s.DueDate = strPtr(due)
		}
		return s
	}
	current := quarterly("2026-04-01", "2026-05-15")
	paidQ3 := map[uuid.UUID]map[string]periodTotal{uuid.New(): {"2026-Q3": {approved: 1000}}}

	amountChanged := quarterly("2026-04-01", "2026-05-15")
	amountChanged.Amount = 2000

	tests := []struct {
		name    string
		mode    string
		updated *domain.DownPaymentScheme
		want    error
	}{
		{"full mode allows anything", domain.SchemeEditFull, amountChanged, nil},
		{"locked rejects date change", domain.SchemeEditLocked, quarterly("2026-04-01", "2026-06-15"), ErrSchemeLocked},
		{"dates only rejects amount change", domain.SchemeEditDatesOnly, amountChanged, ErrSchemeOnlyDates},
		{"dates only allows due date change", domain.SchemeEditDatesOnly, quarterly("2026-04-01", "2026-06-15"), nil},
		{"dates only allows start within paid period", domain.SchemeEditDatesOnly, quarterly("2026-07-01", ""), nil},
		{"dates only rejects start after paid period", domain.SchemeEditDatesOnly, quarterly("2026-10-01", ""), ErrSchemeStartAfterPay},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := checkSchemeEdit(tt.mode, current, tt.updated, paidQ3)
			if !errors.Is(err, tt.want) {
				t.Errorf("checkSchemeEdit() = %v, want %v", err, tt.want)
			}
		})
	}
}
