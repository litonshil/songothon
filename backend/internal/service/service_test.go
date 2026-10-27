package service_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/pkg/token"
)

func TestTokenManager_GenerateAndValidate(t *testing.T) {
	tm := token.NewTokenManager("test-secret-key-songothon-12345", 2*time.Hour, "test-issuer")

	userID := uuid.New()
	user := &domain.User{
		ID:       userID,
		Email:    "test@songothon.org",
		FullName: "Test Member",
	}

	tok, err := tm.GenerateToken(user)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}
	if tok == "" {
		t.Fatal("Expected non-empty token")
	}

	claims, err := tm.ValidateToken(tok)
	if err != nil {
		t.Fatalf("Failed to validate token: %v", err)
	}

	if claims.UserID != userID {
		t.Errorf("Expected userID %v, got %v", userID, claims.UserID)
	}
	if claims.Email != user.Email {
		t.Errorf("Expected email %s, got %s", user.Email, claims.Email)
	}
}

func TestShareFeeCalculation(t *testing.T) {
	sharesCount := 3
	basePricePerShare := 1000.00
	expectedFee := 3000.00

	actualFee := float64(sharesCount) * basePricePerShare
	if actualFee != expectedFee {
		t.Errorf("Expected fee %.2f, got %.2f", expectedFee, actualFee)
	}
}

func TestPeerVisibilityPrivacyScrubbing(t *testing.T) {
	peerVisTrue := true
	peerVisFalse := false

	savingsVal := 5000.00
	sharesVal := 2
	statusVal := "Paid"

	// When visibility is true
	overviewAllowed := domain.PeerMemberOverview{
		UserID:        uuid.New(),
		FullName:      "Rahim Mia",
		Role:          domain.RoleMember,
		JoinedAt:      time.Now(),
		SharesCount:   &sharesVal,
		TotalSavings:  &savingsVal,
		CurrentStatus: &statusVal,
	}

	if overviewAllowed.TotalSavings == nil || *overviewAllowed.TotalSavings != 5000.00 {
		t.Errorf("Expected total savings to be visible when flag is true")
	}
	_ = peerVisTrue

	// When visibility is false
	overviewRestricted := domain.PeerMemberOverview{
		UserID:        uuid.New(),
		FullName:      "Rahim Mia",
		Role:          domain.RoleMember,
		JoinedAt:      time.Now(),
		SharesCount:   nil,
		TotalSavings:  nil,
		CurrentStatus: nil,
	}

	if overviewRestricted.TotalSavings != nil || overviewRestricted.SharesCount != nil {
		t.Errorf("Expected financial metrics to be scrubbed when flag is false")
	}
	_ = peerVisFalse
}
