package postgres

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type SettlementRepository struct {
	db *DB
}

func NewSettlementRepository(db *DB) *SettlementRepository {
	return &SettlementRepository{db: db}
}

// GetStakeTotals returns the member's unsettled approved deposits, the sum of
// unsettled deposits across every current stakeholder (active or suspended
// members, the member included), and the member's pending deposit count.
//
// Deposits already paid out in an earlier settlement (a member who settled,
// rejoined and is settling again) are subtracted so they are never paid twice.
func (r *SettlementRepository) GetStakeTotals(ctx context.Context, orgID, userID uuid.UUID) (memberDeposits, stakeDeposits float64, pendingCount int, err error) {
	query := `
		WITH per_member AS (
			SELECT
				m.user_id,
				GREATEST(
					COALESCE((SELECT SUM(c.amount) FROM contributions c
					          WHERE c.org_id = m.org_id AND c.user_id = m.user_id
					            AND c.status = 'APPROVED' AND c.deleted_at IS NULL), 0)
					- COALESCE((SELECT SUM(s.total_deposits) FROM member_settlements s
					            WHERE s.org_id = m.org_id AND s.user_id = m.user_id), 0),
					0
				)::float8 AS deposits
			FROM organization_members m
			WHERE m.org_id = $1 AND m.status IN ('active', 'suspended') AND m.deleted_at IS NULL
		)
		SELECT
			COALESCE((SELECT deposits FROM per_member WHERE user_id = $2), 0)::float8,
			COALESCE((SELECT SUM(deposits) FROM per_member), 0)::float8,
			(SELECT COUNT(*) FROM contributions
			 WHERE org_id = $1 AND user_id = $2 AND status = 'PENDING' AND deleted_at IS NULL)
	`
	err = r.db.Pool.QueryRow(ctx, query, orgID, userID).Scan(&memberDeposits, &stakeDeposits, &pendingCount)
	if err != nil {
		err = fmt.Errorf("failed to load settlement totals: %w", err)
	}
	return
}

// GetProfitAlreadyPaid sums the profit share handed out in earlier settlements.
func (r *SettlementRepository) GetProfitAlreadyPaid(ctx context.Context, orgID uuid.UUID) (float64, error) {
	var total float64
	err := r.db.Pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(profit_share), 0)::float8 FROM member_settlements WHERE org_id = $1`,
		orgID,
	).Scan(&total)
	return total, err
}

// Create records the settlement, books the payout as a ledger outflow and marks
// the membership 'left', all in one transaction. It fails without changing
// anything if the member is no longer active or suspended.
func (r *SettlementRepository) Create(ctx context.Context, s *domain.MemberSettlement) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Lock the membership row so two admins can't settle the same member at once.
	res, err := tx.Exec(ctx, `
		UPDATE organization_members
		SET status = 'left', role = 'member', left_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND org_id = $2 AND user_id = $3
		  AND status IN ('active', 'suspended') AND deleted_at IS NULL
	`, s.MemberID, s.OrgID, s.UserID)
	if err != nil {
		return fmt.Errorf("failed to update membership: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("member is not active in this organization")
	}

	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	err = tx.QueryRow(ctx, `
		INSERT INTO member_settlements (
			id, org_id, user_id, member_id, total_deposits, profit_share,
			calculated_amount, adjustment, final_amount, org_net_profit, stake_deposits,
			payment_method, trx_id, notes, settled_by, settled_at, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW(), NOW())
		RETURNING settled_at
	`,
		s.ID, s.OrgID, s.UserID, s.MemberID, s.TotalDeposits, s.ProfitShare,
		s.CalculatedAmount, s.Adjustment, s.FinalAmount, s.OrgNetProfit, s.StakeDeposits,
		s.PaymentMethod, s.TrxID, s.Notes, s.SettledBy,
	).Scan(&s.SettledAt)
	if err != nil {
		return fmt.Errorf("failed to record settlement: %w", err)
	}

	// The ledger requires a positive amount; a zero payout moves no money.
	if s.FinalAmount > 0 {
		_, err = tx.Exec(ctx, `
			INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description, created_at)
			VALUES ($1, $2, 'settlement', $3, 'outflow', 'member_settlements', $4, $5, $6, NOW())
		`, uuid.New(), s.OrgID, s.FinalAmount, s.ID, s.SettledBy, "Member settlement payout")
		if err != nil {
			return fmt.Errorf("failed to record settlement ledger entry: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// ListByOrg returns every settlement in the organization, newest first.
func (r *SettlementRepository) ListByOrg(ctx context.Context, orgID uuid.UUID) ([]domain.MemberSettlement, error) {
	rows, err := r.db.Pool.Query(ctx, `
		SELECT
			s.id, s.org_id, s.user_id, s.member_id, u.full_name, u.email,
			s.total_deposits::float8, s.profit_share::float8, s.calculated_amount::float8,
			s.adjustment::float8, s.final_amount::float8, s.org_net_profit::float8, s.stake_deposits::float8,
			s.payment_method, s.trx_id, s.notes, s.settled_by, COALESCE(a.full_name, ''), s.settled_at
		FROM member_settlements s
		JOIN users u ON u.id = s.user_id
		LEFT JOIN users a ON a.id = s.settled_by
		WHERE s.org_id = $1
		ORDER BY s.settled_at DESC
	`, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list settlements: %w", err)
	}
	defer rows.Close()

	list := []domain.MemberSettlement{}
	for rows.Next() {
		var s domain.MemberSettlement
		if err := rows.Scan(
			&s.ID, &s.OrgID, &s.UserID, &s.MemberID, &s.FullName, &s.Email,
			&s.TotalDeposits, &s.ProfitShare, &s.CalculatedAmount,
			&s.Adjustment, &s.FinalAmount, &s.OrgNetProfit, &s.StakeDeposits,
			&s.PaymentMethod, &s.TrxID, &s.Notes, &s.SettledBy, &s.SettledByName, &s.SettledAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan settlement: %w", err)
		}
		list = append(list, s)
	}
	return list, rows.Err()
}
