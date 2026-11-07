package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"html"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
	"songothon/pkg/mailer"
	"songothon/pkg/token"
)

type AuthService struct {
	userRepo *postgres.UserRepository
	orgRepo  *postgres.OrgRepository
	tokenMgr *token.TokenManager
	mailer   *mailer.Mailer
	isProd   bool
}

func NewAuthService(userRepo *postgres.UserRepository, orgRepo *postgres.OrgRepository, tokenMgr *token.TokenManager, m *mailer.Mailer, env string) *AuthService {
	return &AuthService{
		userRepo: userRepo,
		orgRepo:  orgRepo,
		tokenMgr: tokenMgr,
		mailer:   m,
		isProd:   strings.EqualFold(env, "production"),
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

	req.Phone = strings.TrimSpace(req.Phone)
	if req.Phone != "" {
		existingUser, err = s.userRepo.GetByPhone(ctx, req.Phone)
		if err != nil {
			return nil, fmt.Errorf("database query error: %w", err)
		}
		if existingUser != nil {
			return nil, errors.New("a user with this phone number already exists")
		}
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
		Phone:        req.Phone,
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

const (
	resetCodeLength   = 8
	resetCodeTTL      = 30 * time.Minute
	resetCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no 0/O or 1/I
)

// forgotPasswordMessage is returned whether or not the account exists, so the
// endpoint cannot be used to discover which emails are registered.
const forgotPasswordMessage = "If an account exists for this email, a reset code has been sent. It expires in 30 minutes."

// ForgotPassword emails a one-time reset code to the account holder. The code
// is never returned in the API response.
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
		return &domain.ForgotPasswordResponse{Message: forgotPasswordMessage}, nil
	}

	if !s.mailer.Configured() && s.isProd {
		log.Printf("forgot password: SMTP is not configured; cannot email reset code to user %s", user.ID)
		return nil, errors.New("password reset email is temporarily unavailable. Please contact support")
	}

	code, err := generateResetCode()
	if err != nil {
		return nil, fmt.Errorf("failed to generate reset code: %w", err)
	}
	if err := s.userRepo.CreatePasswordResetToken(ctx, user.ID, hashResetCode(code), time.Now().Add(resetCodeTTL)); err != nil {
		return nil, err
	}

	display := code[:4] + "-" + code[4:]
	if !s.mailer.Configured() {
		// Development only: no SMTP server, so print the code for testing.
		log.Printf("[DEV] SMTP not configured. Password reset code for %s: %s", email, display)
		return &domain.ForgotPasswordResponse{Message: forgotPasswordMessage}, nil
	}

	subject, text, htmlBody := resetEmail(user.FullName, display)
	if err := s.mailer.Send(user.Email, subject, text, htmlBody); err != nil {
		log.Printf("forgot password: failed to send reset email to user %s: %v", user.ID, err)
		return nil, errors.New("could not send the reset email right now. Please try again later")
	}

	return &domain.ForgotPasswordResponse{Message: forgotPasswordMessage}, nil
}

func generateResetCode() (string, error) {
	raw := make([]byte, resetCodeLength)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	out := make([]byte, resetCodeLength)
	for i, b := range raw {
		out[i] = resetCodeAlphabet[int(b)%len(resetCodeAlphabet)] // 256 % 32 == 0, so no bias
	}
	return string(out), nil
}

// normalizeResetCode accepts "abcd-efgh", "ABCD EFGH", etc.
func normalizeResetCode(code string) string {
	code = strings.ToUpper(code)
	return strings.Map(func(r rune) rune {
		if r == '-' || r == ' ' || r == '\t' {
			return -1
		}
		return r
	}, code)
}

func hashResetCode(code string) string {
	sum := sha256.Sum256([]byte(normalizeResetCode(code)))
	return hex.EncodeToString(sum[:])
}

func resetEmail(name, code string) (subject, text, htmlBody string) {
	greeting := "Hello"
	if strings.TrimSpace(name) != "" {
		greeting = "Hello " + strings.TrimSpace(name)
	}
	subject = "Your Songothon password reset code"
	text = fmt.Sprintf(`%s,

We received a request to reset your Songothon password.

Your reset code is: %s

Enter this code in the app to choose a new password. It expires in 30 minutes and can be used once.

If you did not request this, you can ignore this email; your password will not change.

— Songothon
`, greeting, code)
	htmlBody = fmt.Sprintf(`<!doctype html>
<html><body style="font-family:Arial,Helvetica,sans-serif;background:#f4f6fa;padding:24px;color:#1b2a41">
  <div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:28px">
    <h2 style="margin:0 0 12px">Reset your password</h2>
    <p>%s,</p>
    <p>We received a request to reset your Songothon password. Enter this code in the app:</p>
    <p style="font-size:28px;font-weight:bold;letter-spacing:4px;text-align:center;background:#eef2f8;border-radius:8px;padding:14px">%s</p>
    <p style="font-size:13px;color:#5b6b82">The code expires in 30 minutes and can be used once. If you did not request this, ignore this email; your password will not change.</p>
  </div>
</body></html>`, html.EscapeString(greeting), html.EscapeString(code))
	return subject, text, htmlBody
}

func (s *AuthService) ResetPassword(ctx context.Context, req *domain.ResetPasswordRequest) error {
	if normalizeResetCode(req.Token) == "" {
		return errors.New("reset code is required")
	}
	if len(req.NewPassword) < 6 {
		return errors.New("new password must be at least 6 characters")
	}

	hashHex := hashResetCode(req.Token)
	userID, err := s.userRepo.GetUserIDByResetToken(ctx, hashHex)
	if err != nil {
		return err
	}
	if userID == uuid.Nil {
		return errors.New("reset code is invalid or has expired")
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
