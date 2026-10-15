package postgres

import (
	"context"
	"errors"
	"fmt"

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

func (r *UserRepository) Create(ctx context.Context, u *domain.User) (*domain.User, error) {
	query := `
		INSERT INTO users (email, password_hash, full_name, phone, role, status)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, email, password_hash, full_name, phone, role, status, created_at, updated_at
	`
	created := &domain.User{}
	err := r.db.Pool.QueryRow(ctx, query,
		u.Email,
		u.PasswordHash,
		u.FullName,
		u.Phone,
		u.Role,
		u.Status,
	).Scan(
		&created.ID,
		&created.Email,
		&created.PasswordHash,
		&created.FullName,
		&created.Phone,
		&created.Role,
		&created.Status,
		&created.CreatedAt,
		&created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return created, nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, role, status, created_at, updated_at
		FROM users
		WHERE id = $1
	`
	u := &domain.User{}
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&u.ID,
		&u.Email,
		&u.PasswordHash,
		&u.FullName,
		&u.Phone,
		&u.Role,
		&u.Status,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get user by id: %w", err)
	}

	return u, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, role, status, created_at, updated_at
		FROM users
		WHERE LOWER(email) = LOWER($1)
	`
	u := &domain.User{}
	err := r.db.Pool.QueryRow(ctx, query, email).Scan(
		&u.ID,
		&u.Email,
		&u.PasswordHash,
		&u.FullName,
		&u.Phone,
		&u.Role,
		&u.Status,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}

	return u, nil
}

func (r *UserRepository) ListMembers(ctx context.Context, status string) ([]domain.User, error) {
	baseQuery := `
		SELECT id, email, full_name, phone, role, status, created_at, updated_at
		FROM users
		WHERE role = 'member'
	`
	var rows pgx.Rows
	var err error

	if status != "" {
		baseQuery += " AND status = $1 ORDER BY created_at DESC"
		rows, err = r.db.Pool.Query(ctx, baseQuery, status)
	} else {
		baseQuery += " ORDER BY created_at DESC"
		rows, err = r.db.Pool.Query(ctx, baseQuery)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to query members: %w", err)
	}
	defer rows.Close()

	var members []domain.User
	for rows.Next() {
		var u domain.User
		if err := rows.Scan(
			&u.ID,
			&u.Email,
			&u.FullName,
			&u.Phone,
			&u.Role,
			&u.Status,
			&u.CreatedAt,
			&u.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan member row: %w", err)
		}
		members = append(members, u)
	}

	return members, nil
}

func (r *UserRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status domain.UserStatus) error {
	query := `
		UPDATE users
		SET status = $1, updated_at = CURRENT_TIMESTAMP
		WHERE id = $2
	`
	res, err := r.db.Pool.Exec(ctx, query, status, id)
	if err != nil {
		return fmt.Errorf("failed to update user status: %w", err)
	}
	if res.RowsAffected() == 0 {
		return errors.New("user not found")
	}

	return nil
}
