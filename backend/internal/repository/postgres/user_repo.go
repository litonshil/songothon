package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"songothon/internal/domain"
)

type UserRepository struct {
	db *DB
}

func NewUserRepository(db *DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, u *domain.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, full_name, phone, fcm_token, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	if u.Status == "" {
		u.Status = domain.UserStatusActive
	}

	err := r.db.Pool.QueryRow(ctx, query,
		u.ID, u.Email, u.PasswordHash, u.FullName, u.Phone, u.FCMToken, u.Status,
	).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, COALESCE(fcm_token, ''), status, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`
	var u domain.User
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.FullName, &u.Phone, &u.FCMToken, &u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user by id: %w", err)
	}
	return &u, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, COALESCE(fcm_token, ''), status, created_at, updated_at
		FROM users
		WHERE LOWER(email) = LOWER($1) AND deleted_at IS NULL
	`
	var u domain.User
	err := r.db.Pool.QueryRow(ctx, query, email).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.FullName, &u.Phone, &u.FCMToken, &u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user by email: %w", err)
	}
	return &u, nil
}

func (r *UserRepository) GetByPhone(ctx context.Context, phone string) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, COALESCE(fcm_token, ''), status, created_at, updated_at
		FROM users
		WHERE phone = $1 AND deleted_at IS NULL
	`
	var u domain.User
	err := r.db.Pool.QueryRow(ctx, query, phone).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.FullName, &u.Phone, &u.FCMToken, &u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user by phone: %w", err)
	}
	return &u, nil
}

func (r *UserRepository) UpdateFCMToken(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	query := `UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.db.Pool.Exec(ctx, query, fcmToken, userID)
	return err
}

func (r *UserRepository) UpdateStatus(ctx context.Context, userID uuid.UUID, status domain.UserStatus) error {
	query := `UPDATE users SET status = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.db.Pool.Exec(ctx, query, status, userID)
	return err
}

func (r *UserRepository) ListMembers(ctx context.Context, status string) ([]domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, COALESCE(fcm_token, ''), status, created_at, updated_at
		FROM users
		WHERE deleted_at IS NULL AND ($1 = '' OR status = $1)
		ORDER BY full_name ASC
	`
	rows, err := r.db.Pool.Query(ctx, query, status)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var list []domain.User
	for rows.Next() {
		var u domain.User
		err := rows.Scan(
			&u.ID, &u.Email, &u.PasswordHash, &u.FullName, &u.Phone, &u.FCMToken, &u.Status, &u.CreatedAt, &u.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		list = append(list, u)
	}
	return list, nil
}

func (r *UserRepository) UpdatePassword(ctx context.Context, userID uuid.UUID, passwordHash string) error {
	query := `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL`
	_, err := r.db.Pool.Exec(ctx, query, passwordHash, userID)
	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}
	return nil
}

func (r *UserRepository) CreatePasswordResetToken(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error {
	// Invalidate any previous unused tokens for this user.
	if _, err := r.db.Pool.Exec(ctx, `UPDATE password_reset_tokens SET used_at = NOW() WHERE user_id = $1 AND used_at IS NULL`, userID); err != nil {
		return fmt.Errorf("failed to invalidate previous reset tokens: %w", err)
	}
	query := `
		INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, NOW())
	`
	_, err := r.db.Pool.Exec(ctx, query, uuid.New(), userID, tokenHash, expiresAt)
	if err != nil {
		return fmt.Errorf("failed to create password reset token: %w", err)
	}
	return nil
}

func (r *UserRepository) GetUserIDByResetToken(ctx context.Context, tokenHash string) (uuid.UUID, error) {
	query := `
		SELECT user_id FROM password_reset_tokens
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()
	`
	var userID uuid.UUID
	err := r.db.Pool.QueryRow(ctx, query, tokenHash).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, nil
	}
	if err != nil {
		return uuid.Nil, fmt.Errorf("failed to validate reset token: %w", err)
	}
	return userID, nil
}

func (r *UserRepository) MarkResetTokenUsed(ctx context.Context, tokenHash string) error {
	_, err := r.db.Pool.Exec(ctx, `UPDATE password_reset_tokens SET used_at = NOW() WHERE token_hash = $1`, tokenHash)
	return err
}
