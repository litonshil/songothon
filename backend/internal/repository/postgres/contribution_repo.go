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

type ContributionRepository struct {
	db *DB
}

func NewContributionRepository(db *DB) *ContributionRepository {
	return &ContributionRepository{db: db}
}

func (r *ContributionRepository) Create(ctx context.Context, c *domain.Contribution) error {
	// Check for existing non-rejected TrxID in the same org
	var existingID uuid.UUID
	checkQuery := `
		SELECT id FROM contributions 
		WHERE org_id = $1 AND LOWER(trx_id) = LOWER($2) AND status != 'REJECTED' AND deleted_at IS NULL
		LIMIT 1
	`
	err := r.db.Pool.QueryRow(ctx, checkQuery, c.OrgID, c.TrxID).Scan(&existingID)
	if err == nil {
		return fmt.Errorf("transaction ID '%s' has already been submitted for this organization", c.TrxID)
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("error verifying transaction ID uniqueness: %w", err)
	}

	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.Status == "" {
		c.Status = domain.ContributionStatusPending
	}
	if c.PaidAt.IsZero() {
		c.PaidAt = time.Now()
	}

	query := `
		INSERT INTO contributions (
			id, org_id, user_id, type, amount, payment_method, trx_id, sender_account,
			receipt_url, target_cycle, status, notes, paid_at, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8,
			$9, $10, $11, $12, $13, NOW(), NOW()
		)
		RETURNING created_at, updated_at
	`
	return r.db.Pool.QueryRow(ctx, query,
		c.ID, c.OrgID, c.UserID, c.Type, c.Amount, c.PaymentMethod, c.TrxID, c.SenderAccount,
		c.ReceiptURL, c.TargetCycle, c.Status, c.Notes, c.PaidAt,
	).Scan(&c.CreatedAt, &c.UpdatedAt)
}

func (r *ContributionRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.ContributionDetail, error) {
	query := `
		SELECT 
			c.id, c.org_id, c.user_id, c.type, c.amount, c.payment_method, c.trx_id, c.sender_account,
			COALESCE(c.receipt_url, ''), c.target_cycle, c.status, c.rejection_reason, c.reviewed_by, c.reviewed_at,
			c.paid_at, COALESCE(c.notes, ''), c.created_at, c.updated_at,
			u.full_name, u.email, COALESCE(u.phone, '')
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		WHERE c.id = $1 AND c.deleted_at IS NULL
	`
	var cd domain.ContributionDetail
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&cd.ID, &cd.OrgID, &cd.UserID, &cd.Type, &cd.Amount, &cd.PaymentMethod, &cd.TrxID, &cd.SenderAccount,
		&cd.ReceiptURL, &cd.TargetCycle, &cd.Status, &cd.RejectionReason, &cd.ReviewedBy, &cd.ReviewedAt,
		&cd.PaidAt, &cd.Notes, &cd.CreatedAt, &cd.UpdatedAt,
		&cd.MemberName, &cd.MemberEmail, &cd.MemberPhone,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch contribution: %w", err)
	}
	return &cd, nil
}

func (r *ContributionRepository) ListPending(ctx context.Context, orgID uuid.UUID) ([]domain.ContributionDetail, error) {
	query := `
		SELECT 
			c.id, c.org_id, c.user_id, c.type, c.amount, c.payment_method, c.trx_id, c.sender_account,
			COALESCE(c.receipt_url, ''), c.target_cycle, c.status, c.rejection_reason, c.reviewed_by, c.reviewed_at,
			c.paid_at, COALESCE(c.notes, ''), c.created_at, c.updated_at,
			u.full_name, u.email, COALESCE(u.phone, '')
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		WHERE c.org_id = $1 AND c.status = 'PENDING' AND c.deleted_at IS NULL
		ORDER BY c.paid_at ASC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.ContributionDetail
	for rows.Next() {
		var cd domain.ContributionDetail
		err := rows.Scan(
			&cd.ID, &cd.OrgID, &cd.UserID, &cd.Type, &cd.Amount, &cd.PaymentMethod, &cd.TrxID, &cd.SenderAccount,
			&cd.ReceiptURL, &cd.TargetCycle, &cd.Status, &cd.RejectionReason, &cd.ReviewedBy, &cd.ReviewedAt,
			&cd.PaidAt, &cd.Notes, &cd.CreatedAt, &cd.UpdatedAt,
			&cd.MemberName, &cd.MemberEmail, &cd.MemberPhone,
		)
		if err != nil {
			return nil, err
		}
		list = append(list, cd)
	}
	return list, nil
}

func (r *ContributionRepository) ListByOrg(ctx context.Context, orgID uuid.UUID, cycle string, status string) ([]domain.ContributionDetail, error) {
	query := `
		SELECT 
			c.id, c.org_id, c.user_id, c.type, c.amount, c.payment_method, c.trx_id, c.sender_account,
			COALESCE(c.receipt_url, ''), c.target_cycle, c.status, c.rejection_reason, c.reviewed_by, c.reviewed_at,
			c.paid_at, COALESCE(c.notes, ''), c.created_at, c.updated_at,
			u.full_name, u.email, COALESCE(u.phone, '')
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		WHERE c.org_id = $1 AND c.deleted_at IS NULL
		  AND ($2 = '' OR c.target_cycle = $2)
		  AND ($3 = '' OR c.status = $3)
		ORDER BY c.paid_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID, cycle, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.ContributionDetail
	for rows.Next() {
		var cd domain.ContributionDetail
		err := rows.Scan(
			&cd.ID, &cd.OrgID, &cd.UserID, &cd.Type, &cd.Amount, &cd.PaymentMethod, &cd.TrxID, &cd.SenderAccount,
			&cd.ReceiptURL, &cd.TargetCycle, &cd.Status, &cd.RejectionReason, &cd.ReviewedBy, &cd.ReviewedAt,
			&cd.PaidAt, &cd.Notes, &cd.CreatedAt, &cd.UpdatedAt,
			&cd.MemberName, &cd.MemberEmail, &cd.MemberPhone,
		)
		if err != nil {
			return nil, err
		}
		list = append(list, cd)
	}
	return list, nil
}

func (r *ContributionRepository) ListByUser(ctx context.Context, orgID, userID uuid.UUID) ([]domain.Contribution, error) {
	query := `
		SELECT 
			id, org_id, user_id, type, amount, payment_method, trx_id, sender_account,
			COALESCE(receipt_url, ''), target_cycle, status, rejection_reason, reviewed_by, reviewed_at,
			paid_at, COALESCE(notes, ''), created_at, updated_at
		FROM contributions
		WHERE org_id = $1 AND user_id = $2 AND deleted_at IS NULL
		ORDER BY paid_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.Contribution
	for rows.Next() {
		var c domain.Contribution
		err := rows.Scan(
			&c.ID, &c.OrgID, &c.UserID, &c.Type, &c.Amount, &c.PaymentMethod, &c.TrxID, &c.SenderAccount,
			&c.ReceiptURL, &c.TargetCycle, &c.Status, &c.RejectionReason, &c.ReviewedBy, &c.ReviewedAt,
			&c.PaidAt, &c.Notes, &c.CreatedAt, &c.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

func (r *ContributionRepository) ApproveDeposit(ctx context.Context, id, reviewerID uuid.UUID) (*domain.ContributionDetail, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update contribution status
	updateQuery := `
		UPDATE contributions
		SET status = 'APPROVED',
		    rejection_reason = NULL,
		    reviewed_by = $2,
		    reviewed_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1 AND status = 'PENDING' AND deleted_at IS NULL
		RETURNING org_id, user_id, amount, target_cycle
	`
	var orgID, memberID uuid.UUID
	var amount float64
	var targetCycle string
	err = tx.QueryRow(ctx, updateQuery, id, reviewerID).Scan(&orgID, &memberID, &amount, &targetCycle)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("deposit not found or already reviewed")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to approve deposit: %w", err)
	}

	// Insert into financial ledger transactions
	ledgerQuery := `
		INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description, created_at)
		VALUES ($1, $2, 'deposit', $3, 'inflow', 'contributions', $4, $5, $6, NOW())
	`
	desc := fmt.Sprintf("Approved member deposit for cycle %s", targetCycle)
	_, err = tx.Exec(ctx, ledgerQuery, uuid.New(), orgID, amount, id, reviewerID, desc)
	if err != nil {
		return nil, fmt.Errorf("failed to record ledger transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit approval transaction: %w", err)
	}

	return r.GetByID(ctx, id)
}

func (r *ContributionRepository) RejectDeposit(ctx context.Context, id, reviewerID uuid.UUID, reason string) (*domain.ContributionDetail, error) {
	query := `
		UPDATE contributions
		SET status = 'REJECTED',
		    rejection_reason = $2,
		    reviewed_by = $3,
		    reviewed_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1 AND status = 'PENDING' AND deleted_at IS NULL
	`
	res, err := r.db.Pool.Exec(ctx, query, id, reason, reviewerID)
	if err != nil {
		return nil, fmt.Errorf("failed to reject deposit: %w", err)
	}
	if res.RowsAffected() == 0 {
		return nil, fmt.Errorf("deposit not found or already reviewed")
	}

	return r.GetByID(ctx, id)
}

func (r *ContributionRepository) GetUserCumulativeDeposits(ctx context.Context, orgID, userID uuid.UUID) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0.0)
		FROM contributions
		WHERE org_id = $1 AND user_id = $2 AND status = 'APPROVED' AND deleted_at IS NULL
	`
	var total float64
	err := r.db.Pool.QueryRow(ctx, query, orgID, userID).Scan(&total)
	return total, err
}

func (r *ContributionRepository) IsCyclePaid(ctx context.Context, orgID, userID uuid.UUID, cycle string) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM contributions
			WHERE org_id = $1 AND user_id = $2 AND target_cycle = $3 AND status = 'APPROVED' AND deleted_at IS NULL
		)
	`
	var paid bool
	err := r.db.Pool.QueryRow(ctx, query, orgID, userID, cycle).Scan(&paid)
	return paid, err
}

func (r *ContributionRepository) GetVaultBalance(ctx context.Context, orgID uuid.UUID) (float64, error) {
	query := `
		SELECT COALESCE(
			SUM(CASE WHEN flow = 'inflow' THEN amount ELSE -amount END),
			0.0
		)
		FROM transactions
		WHERE org_id = $1
	`
	var balance float64
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&balance)
	return balance, err
}

func (r *ContributionRepository) GetCycleStats(ctx context.Context, orgID uuid.UUID, cycle string) (expected, collected, rate float64, err error) {
	// Total Expected for Cycle = SUM(m.shares_count * sc.base_price_per_share)
	expectedQuery := `
		SELECT COALESCE(SUM(m.shares_count * sc.base_price_per_share), 0.0)
		FROM organization_members m
		CROSS JOIN LATERAL (
			SELECT base_price_per_share 
			FROM share_configurations 
			WHERE org_id = $1 AND is_active = true 
			ORDER BY created_at DESC LIMIT 1
		) sc
		WHERE m.org_id = $1 AND m.status = 'active' AND m.deleted_at IS NULL
	`
	_ = r.db.Pool.QueryRow(ctx, expectedQuery, orgID).Scan(&expected)

	// Total Collected for Cycle = SUM(amount) of APPROVED contributions for this cycle
	collectedQuery := `
		SELECT COALESCE(SUM(amount), 0.0)
		FROM contributions
		WHERE org_id = $1 AND target_cycle = $2 AND status = 'APPROVED' AND deleted_at IS NULL
	`
	_ = r.db.Pool.QueryRow(ctx, collectedQuery, orgID, cycle).Scan(&collected)

	if expected > 0 {
		rate = (collected / expected) * 100.0
	} else if collected > 0 {
		rate = 100.0
	}
	return expected, collected, rate, nil
}

func (r *ContributionRepository) GetOrgTotalDeposits(ctx context.Context, orgID uuid.UUID) (float64, error) {
	query := `SELECT COALESCE(SUM(amount), 0.0) FROM contributions WHERE org_id = $1 AND status = 'APPROVED' AND deleted_at IS NULL`
	var total float64
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&total)
	return total, err
}

func (r *ContributionRepository) GetMemberCycleTotals(ctx context.Context, orgID, userID uuid.UUID, cycle string) (approved, pending float64, err error) {
	query := `
		SELECT
			COALESCE(SUM(CASE WHEN status = 'APPROVED' THEN amount ELSE 0 END), 0.0),
			COALESCE(SUM(CASE WHEN status = 'PENDING' THEN amount ELSE 0 END), 0.0)
		FROM contributions
		WHERE org_id = $1 AND user_id = $2 AND target_cycle = $3 AND deleted_at IS NULL
	`
	err = r.db.Pool.QueryRow(ctx, query, orgID, userID, cycle).Scan(&approved, &pending)
	return approved, pending, err
}

func (r *ContributionRepository) GetCurrentCycleStatus(ctx context.Context, orgID, userID uuid.UUID, cycle string) (string, error) {
	approved, pending, err := r.GetMemberCycleTotals(ctx, orgID, userID, cycle)
	if err != nil {
		return "Unpaid", err
	}
	if approved > 0 {
		return "Paid", nil
	}
	if pending > 0 {
		return "Pending", nil
	}
	return "Unpaid", nil
}

func (r *ContributionRepository) GetMemberTargetTotals(ctx context.Context, orgID, userID uuid.UUID, contributionType domain.ContributionType, target string) (approved, pending float64, err error) {
	query := `
		SELECT
			COALESCE(SUM(CASE WHEN status = 'APPROVED' THEN amount ELSE 0 END), 0.0),
			COALESCE(SUM(CASE WHEN status = 'PENDING' THEN amount ELSE 0 END), 0.0)
		FROM contributions
		WHERE org_id = $1 AND user_id = $2 AND type = $3 AND target_cycle = $4 AND deleted_at IS NULL
	`
	err = r.db.Pool.QueryRow(ctx, query, orgID, userID, contributionType, target).Scan(&approved, &pending)
	return approved, pending, err
}
