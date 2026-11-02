package domain

import (
	"testing"
	"time"
)

func strp(s string) *string { return &s }

func day(s string) time.Time {
	t, _ := time.Parse("2006-01-02", s)
	return t.Add(10 * time.Hour)
}

func TestSchemePeriods_Quarterly(t *testing.T) {
	s := DownPaymentScheme{Frequency: "quarterly", StartDate: strp("2026-02-10")}
	got := s.Periods(day("2026-11-02"))
	keys := []string{}
	for _, p := range got {
		keys = append(keys, p.Key)
	}
	want := []string{"2026-Q1", "2026-Q2", "2026-Q3", "2026-Q4"}
	if len(keys) != len(want) {
		t.Fatalf("got %v want %v", keys, want)
	}
	for i := range want {
		if keys[i] != want[i] {
			t.Fatalf("got %v want %v", keys, want)
		}
	}
	q4 := got[3]
	if q4.StartDate != "2026-10-01" || q4.EndDate != "2026-12-31" || q4.DueDate != "2026-12-31" {
		t.Errorf("unexpected Q4: %+v", q4)
	}
	if q4.Label != "Q4 2026 (Oct–Dec)" {
		t.Errorf("label %q", q4.Label)
	}
}

func TestSchemePeriods_QuarterlyDueOffsetRepeats(t *testing.T) {
	// Due 15th of the 2nd month of the quarter.
	s := DownPaymentScheme{Frequency: "quarterly", StartDate: strp("2026-01-01"), DueDate: strp("2026-02-15")}
	if d := s.Period("2026-Q4").DueDate; d != "2026-11-15" {
		t.Errorf("Q4 due %s, want 2026-11-15", d)
	}
	// Day clamps to month end: due 31st of 1st month -> Apr 30 for Q2.
	s.DueDate = strp("2026-01-31")
	if d := s.Period("2026-Q2").DueDate; d != "2026-04-30" {
		t.Errorf("Q2 due %s, want 2026-04-30", d)
	}
}

func TestSchemePeriods_YearlyAndOneTime(t *testing.T) {
	y := DownPaymentScheme{Frequency: "yearly", StartDate: strp("2025-06-01")}
	ps := y.Periods(day("2026-03-01"))
	if len(ps) != 2 || ps[0].Key != "2025" || ps[1].Key != "2026" || ps[1].DueDate != "2026-12-31" {
		t.Errorf("yearly periods %+v", ps)
	}

	o := DownPaymentScheme{Frequency: "one_time", StartDate: strp("2026-11-01")}
	ps = o.Periods(day("2027-05-01"))
	if len(ps) != 1 || ps[0].Key != "once" || ps[0].DueDate != "2026-12-01" {
		t.Errorf("one-time periods %+v", ps)
	}
	o.DueDate = strp("2026-11-20")
	if o.Period("once").DueDate != "2026-11-20" {
		t.Error("one-time due date not honoured")
	}
}

func TestSchemePeriods_NotStartedYet(t *testing.T) {
	s := DownPaymentScheme{Frequency: "quarterly", StartDate: strp("2027-03-01")}
	ps := s.Periods(day("2026-11-02"))
	if len(ps) != 1 || ps[0].Key != "2027-Q1" {
		t.Errorf("expected only the first period, got %+v", ps)
	}
}

func TestSchemePeriod_ValidKeys(t *testing.T) {
	q := DownPaymentScheme{Frequency: "quarterly"}
	for k, ok := range map[string]bool{"2026-Q4": true, "2026-Q5": false, "2026": false, "once": false} {
		if q.ValidPeriodKey(k) != ok {
			t.Errorf("quarterly %q valid=%v", k, !ok)
		}
	}
	o := DownPaymentScheme{Frequency: "one_time"}
	if !o.ValidPeriodKey("once") || o.ValidPeriodKey("2026-11") {
		t.Error("one-time key validation")
	}
}

func TestSchemePeriod_Overdue(t *testing.T) {
	p := SchemePeriod{DueDate: "2026-11-01"}
	if !p.IsPastDue(day("2026-11-02")) || p.IsPastDue(day("2026-11-01")) {
		t.Error("IsPastDue")
	}
	if p.DaysUntilDue(day("2026-10-29")) != 3 {
		t.Errorf("DaysUntilDue = %d", p.DaysUntilDue(day("2026-10-29")))
	}
}
