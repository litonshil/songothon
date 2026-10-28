package domain

import "testing"

func TestCycleStatus(t *testing.T) {
	tests := []struct {
		name     string
		approved float64
		pending  float64
		expected float64
		want     string
	}{
		{"nothing paid", 0, 0, 1000, "Unpaid"},
		{"submitted, not approved", 0, 1000, 1000, "Pending"},
		{"partially approved", 400, 0, 1000, "Partially Paid"},
		{"partially approved with another pending", 400, 300, 1000, "Partially Paid"},
		{"exactly due", 1000, 0, 1000, "Paid"},
		{"overpaid", 1500, 0, 1000, "Paid"},
		{"zero due with approved amount", 500, 0, 0, "Paid"},
		{"zero due nothing approved", 0, 0, 0, "Unpaid"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := CycleStatus(tt.approved, tt.pending, tt.expected); got != tt.want {
				t.Errorf("CycleStatus(%v, %v, %v) = %q, want %q", tt.approved, tt.pending, tt.expected, got, tt.want)
			}
		})
	}
}
