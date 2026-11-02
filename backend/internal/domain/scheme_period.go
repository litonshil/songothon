package domain

import (
	"fmt"
	"regexp"
	"strconv"
	"time"
)

// Down payment schemes are billed per period. Every active member owes the
// scheme's flat amount for every period from the scheme's start up to and
// including the current one, regardless of when they joined.
//
// Period keys (stored in contributions.target_cycle):
//   one_time  -> "once"
//   quarterly -> "2026-Q4" (calendar quarter)
//   yearly    -> "2026"    (calendar year)

const (
	SchemeFrequencyOneTime   = "one_time"
	SchemeFrequencyQuarterly = "quarterly"
	SchemeFrequencyYearly    = "yearly"

	SchemePeriodOnce = "once"

	oneTimeDefaultDueDays = 30
	dateLayout            = "2006-01-02"
)

type SchemePeriod struct {
	Key       string `json:"key"`
	Label     string `json:"label"`
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date,omitempty"`
	DueDate   string `json:"due_date"`
}

var (
	quarterKeyRe = regexp.MustCompile(`^(\d{4})-Q([1-4])$`)
	yearKeyRe    = regexp.MustCompile(`^(\d{4})$`)
)

// SchemeStart is the scheme's start date (falling back to its creation date).
func (s *DownPaymentScheme) SchemeStart() time.Time {
	if s.StartDate != nil {
		if t, err := time.Parse(dateLayout, *s.StartDate); err == nil {
			return t
		}
	}
	return dateOnly(s.CreatedAt)
}

// PeriodKeyFor returns the key of the period that contains date t.
func (s *DownPaymentScheme) PeriodKeyFor(t time.Time) string {
	switch s.Frequency {
	case SchemeFrequencyQuarterly:
		return fmt.Sprintf("%d-Q%d", t.Year(), (int(t.Month())-1)/3+1)
	case SchemeFrequencyYearly:
		return strconv.Itoa(t.Year())
	default:
		return SchemePeriodOnce
	}
}

// ValidPeriodKey reports whether key is a well-formed period for this scheme's frequency.
func (s *DownPaymentScheme) ValidPeriodKey(key string) bool {
	_, ok := s.periodBounds(key)
	return ok
}

// Periods lists every period from the scheme start through the period
// containing now (or just the first period if the scheme has not started).
func (s *DownPaymentScheme) Periods(now time.Time) []SchemePeriod {
	start := s.SchemeStart()
	if s.Frequency != SchemeFrequencyQuarterly && s.Frequency != SchemeFrequencyYearly {
		return []SchemePeriod{s.Period(SchemePeriodOnce)}
	}

	last := dateOnly(now)
	if last.Before(start) {
		last = start
	}
	var out []SchemePeriod
	for key := s.PeriodKeyFor(start); ; {
		p := s.Period(key)
		out = append(out, p)
		if key == s.PeriodKeyFor(last) || len(out) > 500 {
			break
		}
		end, _ := time.Parse(dateLayout, p.EndDate)
		key = s.PeriodKeyFor(end.AddDate(0, 0, 1))
	}
	return out
}

// PeriodAt is the period containing now (or the first, if not yet started).
func (s *DownPaymentScheme) PeriodAt(now time.Time) SchemePeriod {
	periods := s.Periods(now)
	return periods[len(periods)-1]
}

// Period describes one period by key. The key must be valid for the scheme.
func (s *DownPaymentScheme) Period(key string) SchemePeriod {
	b, _ := s.periodBounds(key)
	p := SchemePeriod{Key: key, StartDate: b.start.Format(dateLayout), Label: b.label}
	if !b.end.IsZero() {
		p.EndDate = b.end.Format(dateLayout)
	}
	p.DueDate = s.dueDateFor(b).Format(dateLayout)
	return p
}

type periodBounds struct {
	start, end time.Time // end is zero for one-time schemes
	label      string
}

func (s *DownPaymentScheme) periodBounds(key string) (periodBounds, bool) {
	switch s.Frequency {
	case SchemeFrequencyQuarterly:
		m := quarterKeyRe.FindStringSubmatch(key)
		if m == nil {
			return periodBounds{}, false
		}
		year, _ := strconv.Atoi(m[1])
		q, _ := strconv.Atoi(m[2])
		start := time.Date(year, time.Month((q-1)*3+1), 1, 0, 0, 0, 0, time.UTC)
		end := start.AddDate(0, 3, -1)
		label := fmt.Sprintf("Q%d %d (%s–%s)", q, year, start.Format("Jan"), end.Format("Jan"))
		return periodBounds{start: start, end: end, label: label}, true
	case SchemeFrequencyYearly:
		if !yearKeyRe.MatchString(key) {
			return periodBounds{}, false
		}
		year, _ := strconv.Atoi(key)
		start := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
		return periodBounds{start: start, end: start.AddDate(1, 0, -1), label: key}, true
	default:
		if key != SchemePeriodOnce {
			return periodBounds{}, false
		}
		return periodBounds{start: s.SchemeStart(), label: "One-time"}, true
	}
}

// dueDateFor: a one-time scheme is due on its due date (or 30 days after it
// starts). For recurring schemes the configured due date sets the offset into
// the first period (e.g. "the 15th of the 2nd month") and every later period
// repeats it; without one, a period is due on its last day.
func (s *DownPaymentScheme) dueDateFor(b periodBounds) time.Time {
	var configured *time.Time
	if s.DueDate != nil {
		if t, err := time.Parse(dateLayout, *s.DueDate); err == nil {
			configured = &t
		}
	}

	if b.end.IsZero() { // one_time
		if configured != nil {
			return *configured
		}
		return b.start.AddDate(0, 0, oneTimeDefaultDueDays)
	}
	if configured == nil {
		return b.end
	}

	first, _ := s.periodBounds(s.PeriodKeyFor(s.SchemeStart()))
	monthOffset := (configured.Year()-first.start.Year())*12 + int(configured.Month()-first.start.Month())
	if monthOffset < 0 {
		return b.end
	}
	monthStart := b.start.AddDate(0, monthOffset, 0)
	day := configured.Day()
	if last := monthStart.AddDate(0, 1, -1).Day(); day > last {
		day = last
	}
	return time.Date(monthStart.Year(), monthStart.Month(), day, 0, 0, 0, 0, time.UTC)
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// IsPastDue reports whether the period's due date is before today.
func (p SchemePeriod) IsPastDue(now time.Time) bool {
	due, err := time.Parse(dateLayout, p.DueDate)
	return err == nil && dateOnly(now).After(due)
}

// DaysUntilDue is negative when overdue.
func (p SchemePeriod) DaysUntilDue(now time.Time) int {
	due, err := time.Parse(dateLayout, p.DueDate)
	if err != nil {
		return 0
	}
	return int(due.Sub(dateOnly(now)).Hours() / 24)
}
