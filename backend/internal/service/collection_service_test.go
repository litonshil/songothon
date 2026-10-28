package service

import (
	"reflect"
	"testing"
	"time"
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
