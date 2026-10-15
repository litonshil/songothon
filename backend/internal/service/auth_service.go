package service

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
	"songothon/pkg/token"
)

type AuthService struct {
	userRepo *postgres.UserRepository
	tokenMgr *token.TokenManager
}

func NewAuthService(userRepo *postgres.UserRepository, tokenMgr *token.TokenManager) *AuthService {
	return &AuthService{
		userRepo: userRepo,
		tokenMgr: tokenMgr,
	}
}

func (s *AuthService) Register(ctx context.Context, req *domain.RegisterRequest) (*domain.AuthResponse, error) {
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" || req.Password == "" || req.FullName == "" {
		return nil, errors.New("email, password, and full name are required")
	}

	existing, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, errors.New("a user with this email already exists")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("failed to hash password")
	}

	role := domain.RoleMember
	if req.Role == domain.RoleAdmin {
		role = domain.RoleAdmin
	}

	user := &domain.User{
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		FullName:     strings.TrimSpace(req.FullName),
		Phone:        strings.TrimSpace(req.Phone),
		Role:         role,
		Status:       domain.UserStatusActive,
	}

	created, err := s.userRepo.Create(ctx, user)
	if err != nil {
		return nil, err
	}

	jwtToken, err := s.tokenMgr.GenerateToken(created)
	if err != nil {
		return nil, errors.New("failed to generate authentication token")
	}

	return &domain.AuthResponse{
		Token: jwtToken,
		User:  created.ToResponse(),
	}, nil
}

func (s *AuthService) Login(ctx context.Context, req *domain.LoginRequest) (*domain.AuthResponse, error) {
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" || req.Password == "" {
		return nil, errors.New("email and password are required")
	}

	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("invalid email or password")
	}

	if user.Status != domain.UserStatusActive {
		return nil, errors.New("your account is " + string(user.Status) + ", please contact admin")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("invalid email or password")
	}

	jwtToken, err := s.tokenMgr.GenerateToken(user)
	if err != nil {
		return nil, errors.New("failed to generate authentication token")
	}

	return &domain.AuthResponse{
		Token: jwtToken,
		User:  user.ToResponse(),
	}, nil
}

func (s *AuthService) GetProfile(ctx context.Context, userID uuid.UUID) (*domain.UserResponse, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	res := user.ToResponse()
	return &res, nil
}
