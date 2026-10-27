package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
	"songothon/pkg/token"
)

type AuthService struct {
	userRepo *postgres.UserRepository
	orgRepo  *postgres.OrgRepository
	tokenMgr *token.TokenManager
}

func NewAuthService(userRepo *postgres.UserRepository, orgRepo *postgres.OrgRepository, tokenMgr *token.TokenManager) *AuthService {
	return &AuthService{
		userRepo: userRepo,
		orgRepo:  orgRepo,
		tokenMgr: tokenMgr,
	}
}

func (s *AuthService) Register(ctx context.Context, req *domain.RegisterRequest) (*domain.AuthResponse, error) {
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" {
		return nil, errors.New("email is required")
	}
	if len(req.Password) < 6 {
		return nil, errors.New("password must be at least 6 characters")
	}

	existingUser, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("database query error: %w", err)
	}
	if existingUser != nil {
		return nil, errors.New("a user with this email address already exists")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	user := &domain.User{
		ID:           uuid.New(),
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		FullName:     strings.TrimSpace(req.FullName),
		Phone:        strings.TrimSpace(req.Phone),
		Status:       domain.UserStatusActive,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to save user: %w", err)
	}

	// Link any pending invitations addressed to this email address or phone.
	_ = s.orgRepo.AcceptPendingInvitations(ctx, user)

	jwtToken, err := s.tokenMgr.GenerateToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	return &domain.AuthResponse{
		Token: jwtToken,
		User:  user.ToResponse(),
	}, nil
}

func (s *AuthService) Login(ctx context.Context, req *domain.LoginRequest) (*domain.AuthResponse, error) {
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" || req.Password == "" {
		return nil, errors.New("email and password are required")
	}

	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("database query error: %w", err)
	}
	if user == nil {
		return nil, errors.New("invalid email or password")
	}

	if user.Status == domain.UserStatusDeactivated {
		return nil, errors.New("account has been deactivated. Please contact support")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("invalid email or password")
	}

	jwtToken, err := s.tokenMgr.GenerateToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	return &domain.AuthResponse{
		Token: jwtToken,
		User:  user.ToResponse(),
	}, nil
}

func (s *AuthService) Me(ctx context.Context, userID uuid.UUID) (*domain.UserResponse, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user: %w", err)
	}
	if user == nil {
		return nil, errors.New("user not found")
	}
	resp := user.ToResponse()
	return &resp, nil
}

func (s *AuthService) UpdateFCMToken(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	return s.userRepo.UpdateFCMToken(ctx, userID, fcmToken)
}

// Logout clears the FCM token so the device stops receiving push notifications.
// JWT is stateless and is invalidated client-side by deleting the stored token.
func (s *AuthService) Logout(ctx context.Context, userID uuid.UUID) error {
	return s.userRepo.UpdateFCMToken(ctx, userID, "")
}

func (s *AuthService) ForgotPassword(ctx context.Context, email string) (*domain.ForgotPasswordResponse, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" {
		return nil, errors.New("email is required")
	}

	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil, fmt.Errorf("database query error: %w", err)
	}
	if user == nil {
		return nil, errors.New("no account found with this email address")
	}

	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return nil, fmt.Errorf("failed to generate reset token: %w", err)
	}
	resetToken := hex.EncodeToString(raw)
	tokenHash := sha256.Sum256([]byte(resetToken))
	if err := s.userRepo.CreatePasswordResetToken(ctx, user.ID, hex.EncodeToString(tokenHash[:]), time.Now().Add(30*time.Minute)); err != nil {
		return nil, err
	}

	return &domain.ForgotPasswordResponse{
		Message:    "Password reset token generated. It expires in 30 minutes.",
		ResetToken: resetToken,
	}, nil
}

func (s *AuthService) ResetPassword(ctx context.Context, req *domain.ResetPasswordRequest) error {
	if strings.TrimSpace(req.Token) == "" {
		return errors.New("reset token is required")
	}
	if len(req.NewPassword) < 6 {
		return errors.New("new password must be at least 6 characters")
	}

	tokenHash := sha256.Sum256([]byte(strings.TrimSpace(req.Token)))
	hashHex := hex.EncodeToString(tokenHash[:])
	userID, err := s.userRepo.GetUserIDByResetToken(ctx, hashHex)
	if err != nil {
		return err
	}
	if userID == uuid.Nil {
		return errors.New("reset token is invalid or has expired")
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}
	if err := s.userRepo.UpdatePassword(ctx, userID, string(hashed)); err != nil {
		return err
	}
	_ = s.userRepo.MarkResetTokenUsed(ctx, hashHex)
	return nil
}
