package service

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type MemberService struct {
	userRepo *postgres.UserRepository
}

func NewMemberService(userRepo *postgres.UserRepository) *MemberService {
	return &MemberService{userRepo: userRepo}
}

func (s *MemberService) ListMembers(ctx context.Context, status string) ([]domain.UserResponse, error) {
	users, err := s.userRepo.ListMembers(ctx, status)
	if err != nil {
		return nil, err
	}

	res := make([]domain.UserResponse, len(users))
	for i, u := range users {
		res[i] = u.ToResponse()
	}

	return res, nil
}

func (s *MemberService) UpdateMemberStatus(ctx context.Context, id uuid.UUID, status domain.UserStatus) error {
	if status != domain.UserStatusActive && status != domain.UserStatusPending && status != domain.UserStatusDeactivated {
		return errors.New("invalid status: must be active, pending, or deactivated")
	}

	return s.userRepo.UpdateStatus(ctx, id, status)
}
