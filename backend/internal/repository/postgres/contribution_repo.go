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

func (r *ContributionRepository) CreatePeriod(ctx context.Context, p *domain.ContributionPeriod) (*domain.ContributionPeriod, error) {
	query := `
		INSERT INTO contribution_periods (title, frequency, amount_due, due_date, is_active)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, title, frequency, amount_due, due_date, is_active, created_at, updated_at
	`
	created := &domain.ContributionPeriod{}
	err := r.db.Pool.QueryRow(ctx, query,
		p.Title,
		p.Frequency,
		p.AmountDue,
		p.DueDate,
		p.IsActive,
	).Scan(
		&created.ID,
		&created.Title,
		&created.Frequency,
		&created.AmountDue,
		&created.DueDate,
		&created.IsActive,
		&created.CreatedAt,
		&created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create contribution period: %w", err)
	}

	return created, nil
}

func (r *ContributionRepository) GetPeriodByID(ctx context.Context, id uuid.UUID) (*domain.ContributionPeriod, error) {
	query := `
		SELECT id, title, frequency, amount_due, due_date, is_active, created_at, updated_at
		FROM contribution_periods
		WHERE id = $1
	`
	p := &domain.ContributionPeriod{}
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&p.ID,
		&p.Title,
		&p.Frequency,
		&p.AmountDue,
		&p.DueDate,
		&p.IsActive,
		&p.CreatedAt,
		&p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get contribution period: %w", err)
	}

	return p, nil
}

func (r *ContributionRepository) GetActivePeriod(ctx context.Context) (*domain.ContributionPeriod, error) {
	query := `
		SELECT id, title, frequency, amount_due, due_date, is_active, created_at, updated_at
		FROM contribution_periods
		WHERE is_active = true
		ORDER BY due_date DESC
		LIMIT 1
	`
	p := &domain.ContributionPeriod{}
	err := r.db.Pool.QueryRow(ctx, query).Scan(
		&p.ID,
		&p.Title,
		&p.Frequency,
		&p.AmountDue,
		&p.DueDate,
		&p.IsActive,
		&p.CreatedAt,
		&p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get active period: %w", err)
	}

	return p, nil
}

func (r *ContributionRepository) ListPeriods(ctx context.Context, activeOnly bool) ([]domain.ContributionPeriod, error) {
	query := `
		SELECT id, title, frequency, amount_due, due_date, is_active, created_at, updated_at
		FROM contribution_periods
	`
	if activeOnly {
		query += " WHERE is_active = true"
	}
	query += " ORDER BY due_date DESC"

	rows, err := r.db.Pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query periods: %w", err)
	}
	defer rows.Close()

	var periods []domain.ContributionPeriod
	for rows.Next() {
		var p domain.ContributionPeriod
		if err := rows.Scan(
			&p.ID,
			&p.Title,
			&p.Frequency,
			&p.AmountDue,
			&p.DueDate,
			&p.IsActive,
			&p.CreatedAt,
			&p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan period: %w", err)
		}
		periods = append(periods, p)
	}

	return periods, nil
}

// SubmitDeposit handles member self-submission of a monthly deposit (Status: Pending)
func (r *ContributionRepository) SubmitDeposit(ctx context.Context, c *domain.Contribution) (*domain.Contribution, error) {
	query := `
		INSERT INTO contributions (user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes)
		VALUES ($1, $2, $3, $4, $5, 'pending', NULL, $6, $7)
		RETURNING id, user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes, created_at, updated_at
	`
	created := &domain.Contribution{}
	err := r.db.Pool.QueryRow(ctx, query,
		c.UserID,
		c.PeriodID,
		c.Amount,
		c.PaymentMethod,
		c.ReferenceNo,
		c.PaidAt,
		c.Notes,
	).Scan(
		&created.ID,
		&created.UserID,
		&created.PeriodID,
		&created.Amount,
		&created.PaymentMethod,
		&created.ReferenceNo,
		&created.Status,
		&created.RecordedBy,
		&created.PaidAt,
		&created.Notes,
		&created.CreatedAt,
		&created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to submit deposit: %w", err)
	}

	return created, nil
}

// ApproveDeposit approves a pending deposit, marks as paid, and posts into transactions ledger
func (r *ContributionRepository) ApproveDeposit(ctx context.Context, contributionID, adminID uuid.UUID) (*domain.Contribution, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Fetch existing contribution
	var c domain.Contribution
	checkQuery := `
		SELECT c.id, c.user_id, u.full_name, c.amount, c.status
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		WHERE c.id = $1
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkQuery, contributionID).Scan(
		&c.ID,
		&c.UserID,
		&c.MemberName,
		&c.Amount,
		&c.Status,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("deposit record not found")
		}
		return nil, fmt.Errorf("failed to find deposit: %w", err)
	}

	if c.Status == domain.ContributionPaid {
		return nil, errors.New("deposit is already approved and paid")
	}

	// Update contribution status to paid
	updateQuery := `
		UPDATE contributions
		SET status = 'paid', recorded_by = $1, paid_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
		WHERE id = $2
		RETURNING id, user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes, created_at, updated_at
	`
	updated := &domain.Contribution{}
	err = tx.QueryRow(ctx, updateQuery, adminID, contributionID).Scan(
		&updated.ID,
		&updated.UserID,
		&updated.PeriodID,
		&updated.Amount,
		&updated.PaymentMethod,
		&updated.ReferenceNo,
		&updated.Status,
		&updated.RecordedBy,
		&updated.PaidAt,
		&updated.Notes,
		&updated.CreatedAt,
		&updated.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to approve deposit: %w", err)
	}

	// Post into transactions ledger
	insertTxQuery := `
		INSERT INTO transactions (type, amount, flow, reference_table, reference_id, recorded_by, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	desc := fmt.Sprintf("Approved member deposit of %.2f from %s", updated.Amount, c.MemberName)
	_, err = tx.Exec(ctx, insertTxQuery,
		domain.TxDeposit,
		updated.Amount,
		domain.FlowInflow,
		"contributions",
		updated.ID,
		adminID,
		desc,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to record ledger transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit approval transaction: %w", err)
	}

	return updated, nil
}

// RejectDeposit marks a pending deposit as rejected with an optional reason
func (r *ContributionRepository) RejectDeposit(ctx context.Context, contributionID, adminID uuid.UUID, reason string) error {
	query := `
		UPDATE contributions
		SET status = 'rejected', recorded_by = $1, notes = COALESCE(notes || ' | ', '') || $2, updated_at = CURRENT_TIMESTAMP
		WHERE id = $3 AND status = 'pending'
	`
	res, err := r.db.Pool.Exec(ctx, query, adminID, "Rejected: "+reason, contributionID)
	if err != nil {
		return fmt.Errorf("failed to reject deposit: %w", err)
	}
	if res.RowsAffected() == 0 {
		return errors.New("deposit not found or not in pending status")
	}

	return nil
}

// RecordDeposit directly records an approved deposit by admin
func (r *ContributionRepository) RecordDeposit(ctx context.Context, c *domain.Contribution) (*domain.Contribution, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	insertContributionQuery := `
		INSERT INTO contributions (user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes)
		VALUES ($1, $2, $3, $4, $5, 'paid', $6, $7, $8)
		RETURNING id, user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes, created_at, updated_at
	`
	created := &domain.Contribution{}
	err = tx.QueryRow(ctx, insertContributionQuery,
		c.UserID,
		c.PeriodID,
		c.Amount,
		c.PaymentMethod,
		c.ReferenceNo,
		c.RecordedBy,
		c.PaidAt,
		c.Notes,
	).Scan(
		&created.ID,
		&created.UserID,
		&created.PeriodID,
		&created.Amount,
		&created.PaymentMethod,
		&created.ReferenceNo,
		&created.Status,
		&created.RecordedBy,
		&created.PaidAt,
		&created.Notes,
		&created.CreatedAt,
		&created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert contribution: %w", err)
	}

	// Ledger record
	insertTxQuery := `
		INSERT INTO transactions (type, amount, flow, reference_table, reference_id, recorded_by, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	desc := fmt.Sprintf("Admin recorded deposit of %.2f", c.Amount)
	_, err = tx.Exec(ctx, insertTxQuery,
		domain.TxDeposit,
		c.Amount,
		domain.FlowInflow,
		"contributions",
		created.ID,
		c.RecordedBy,
		desc,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to record ledger transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit deposit transaction: %w", err)
	}

	return created, nil
}

// ListMonthlyDeposits returns member deposits grouped by a specific month/period
func (r *ContributionRepository) ListMonthlyDeposits(ctx context.Context, periodID uuid.UUID) (*domain.MonthlyDepositReport, error) {
	period, err := r.GetPeriodByID(ctx, periodID)
	if err != nil {
		return nil, err
	}
	if period == nil {
		return nil, errors.New("contribution period not found")
	}

	query := `
		SELECT c.id, c.user_id, u.full_name, u.email, c.period_id, COALESCE(p.title, 'General Savings'),
		       c.amount, c.payment_method, COALESCE(c.reference_no, ''), c.status,
		       c.recorded_by, COALESCE(rec.full_name, 'Pending Approval'), c.paid_at, COALESCE(c.notes, ''),
		       c.created_at, c.updated_at
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN contribution_periods p ON c.period_id = p.id
		LEFT JOIN users rec ON c.recorded_by = rec.id
		WHERE c.period_id = $1
		ORDER BY c.status ASC, c.paid_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, periodID)
	if err != nil {
		return nil, fmt.Errorf("failed to query monthly deposits: %w", err)
	}
	defer rows.Close()

	var deposits []domain.Contribution
	var totalCollected float64
	var totalPending float64
	var paidCount int
	var pendingCount int

	for rows.Next() {
		var c domain.Contribution
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.MemberName,
			&c.MemberEmail,
			&c.PeriodID,
			&c.PeriodTitle,
			&c.Amount,
			&c.PaymentMethod,
			&c.ReferenceNo,
			&c.Status,
			&c.RecordedBy,
			&c.RecorderName,
			&c.PaidAt,
			&c.Notes,
			&c.CreatedAt,
			&c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan deposit: %w", err)
		}

		if c.Status == domain.ContributionPaid {
			totalCollected += c.Amount
			paidCount++
		} else if c.Status == domain.ContributionPending {
			totalPending += c.Amount
			pendingCount++
		}

		deposits = append(deposits, c)
	}

	return &domain.MonthlyDepositReport{
		PeriodID:       period.ID,
		PeriodTitle:    period.Title,
		AmountDue:      period.AmountDue,
		DueDate:        period.DueDate,
		TotalCollected: totalCollected,
		TotalPending:   totalPending,
		PaidCount:      paidCount,
		PendingCount:   pendingCount,
		Deposits:       deposits,
	}, nil
}

// ListAllMonthlyReports returns all monthly cycles with their member deposits
func (r *ContributionRepository) ListAllMonthlyReports(ctx context.Context) ([]domain.MonthlyDepositReport, error) {
	periods, err := r.ListPeriods(ctx, false)
	if err != nil {
		return nil, err
	}

	var reports []domain.MonthlyDepositReport
	for _, p := range periods {
		report, err := r.ListMonthlyDeposits(ctx, p.ID)
		if err == nil && report != nil {
			reports = append(reports, *report)
		}
	}

	return reports, nil
}

// ListPendingApprovals lists deposits awaiting admin approval
func (r *ContributionRepository) ListPendingApprovals(ctx context.Context) ([]domain.Contribution, error) {
	query := `
		SELECT c.id, c.user_id, u.full_name, u.email, c.period_id, COALESCE(p.title, 'General Savings'),
		       c.amount, c.payment_method, COALESCE(c.reference_no, ''), c.status,
		       c.recorded_by, 'Pending Admin', c.paid_at, COALESCE(c.notes, ''),
		       c.created_at, c.updated_at
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN contribution_periods p ON c.period_id = p.id
		WHERE c.status = 'pending'
		ORDER BY c.created_at ASC
	`
	rows, err := r.db.Pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query pending deposits: %w", err)
	}
	defer rows.Close()

	var list []domain.Contribution
	for rows.Next() {
		var c domain.Contribution
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.MemberName,
			&c.MemberEmail,
			&c.PeriodID,
			&c.PeriodTitle,
			&c.Amount,
			&c.PaymentMethod,
			&c.ReferenceNo,
			&c.Status,
			&c.RecordedBy,
			&c.RecorderName,
			&c.PaidAt,
			&c.Notes,
			&c.CreatedAt,
			&c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan pending deposit: %w", err)
		}
		list = append(list, c)
	}

	return list, nil
}

func (r *ContributionRepository) ListUserContributions(ctx context.Context, userID uuid.UUID) ([]domain.Contribution, error) {
	query := `
		SELECT c.id, c.user_id, u.full_name, u.email, c.period_id, COALESCE(p.title, 'General Savings'),
		       c.amount, c.payment_method, COALESCE(c.reference_no, ''), c.status,
		       c.recorded_by, COALESCE(rec.full_name, 'System'), c.paid_at, COALESCE(c.notes, ''),
		       c.created_at, c.updated_at
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN contribution_periods p ON c.period_id = p.id
		LEFT JOIN users rec ON c.recorded_by = rec.id
		WHERE c.user_id = $1
		ORDER BY c.paid_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query user contributions: %w", err)
	}
	defer rows.Close()

	var list []domain.Contribution
	for rows.Next() {
		var c domain.Contribution
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.MemberName,
			&c.MemberEmail,
			&c.PeriodID,
			&c.PeriodTitle,
			&c.Amount,
			&c.PaymentMethod,
			&c.ReferenceNo,
			&c.Status,
			&c.RecordedBy,
			&c.RecorderName,
			&c.PaidAt,
			&c.Notes,
			&c.CreatedAt,
			&c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan user contribution: %w", err)
		}
		list = append(list, c)
	}

	return list, nil
}

func (r *ContributionRepository) ListAllContributions(ctx context.Context, limit, offset int) ([]domain.Contribution, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT c.id, c.user_id, u.full_name, u.email, c.period_id, COALESCE(p.title, 'General Savings'),
		       c.amount, c.payment_method, COALESCE(c.reference_no, ''), c.status,
		       c.recorded_by, COALESCE(rec.full_name, 'System'), c.paid_at, COALESCE(c.notes, ''),
		       c.created_at, c.updated_at
		FROM contributions c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN contribution_periods p ON c.period_id = p.id
		LEFT JOIN users rec ON c.recorded_by = rec.id
		ORDER BY c.paid_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query all contributions: %w", err)
	}
	defer rows.Close()

	var list []domain.Contribution
	for rows.Next() {
		var c domain.Contribution
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.MemberName,
			&c.MemberEmail,
			&c.PeriodID,
			&c.PeriodTitle,
			&c.Amount,
			&c.PaymentMethod,
			&c.ReferenceNo,
			&c.Status,
			&c.RecordedBy,
			&c.RecorderName,
			&c.PaidAt,
			&c.Notes,
			&c.CreatedAt,
			&c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan contribution: %w", err)
		}
		list = append(list, c)
	}

	return list, nil
}

func (r *ContributionRepository) GetUserFinancialSummary(ctx context.Context, userID uuid.UUID) (*domain.MemberFinancialSummary, error) {
	userQuery := `SELECT full_name, email FROM users WHERE id = $1`
	var fullName, email string
	err := r.db.Pool.QueryRow(ctx, userQuery, userID).Scan(&fullName, &email)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// Total contributed by user (only paid counts)
	contributedQuery := `
		SELECT COALESCE(SUM(amount), 0.00)
		FROM contributions
		WHERE user_id = $1 AND status = 'paid'
	`
	var totalContributed float64
	err = r.db.Pool.QueryRow(ctx, contributedQuery, userID).Scan(&totalContributed)
	if err != nil {
		return nil, fmt.Errorf("failed to query total contributed: %w", err)
	}

	// Total active/past periods required sum vs paid count
	periodSummaryQuery := `
		SELECT COUNT(*), COALESCE(SUM(amount_due), 0.00)
		FROM contribution_periods
		WHERE due_date <= $1
	`
	var totalCycles int
	var totalObligation float64
	err = r.db.Pool.QueryRow(ctx, periodSummaryQuery, time.Now().AddDate(0, 0, 1)).Scan(&totalCycles, &totalObligation)
	if err != nil {
		return nil, fmt.Errorf("failed to query period obligations: %w", err)
	}

	// Paid periods count
	paidCyclesQuery := `
		SELECT COUNT(DISTINCT period_id)
		FROM contributions
		WHERE user_id = $1 AND status = 'paid' AND period_id IS NOT NULL
	`
	var paidCycles int
	_ = r.db.Pool.QueryRow(ctx, paidCyclesQuery, userID).Scan(&paidCycles)

	// Pending periods count
	pendingCyclesQuery := `
		SELECT COUNT(DISTINCT period_id)
		FROM contributions
		WHERE user_id = $1 AND status = 'pending' AND period_id IS NOT NULL
	`
	var pendingCycles int
	_ = r.db.Pool.QueryRow(ctx, pendingCyclesQuery, userID).Scan(&pendingCycles)

	pendingDues := totalObligation - totalContributed
	if pendingDues < 0 {
		pendingDues = 0
	}

	recentContributions, err := r.ListUserContributions(ctx, userID)
	if err != nil {
		recentContributions = []domain.Contribution{}
	}

	return &domain.MemberFinancialSummary{
		UserID:            userID,
		FullName:          fullName,
		Email:             email,
		TotalContributed:  totalContributed,
		PendingDues:       pendingDues,
		TotalCycles:       totalCycles,
		PaidCycles:        paidCycles,
		PendingCycles:     pendingCycles,
		ContributionsList: recentContributions,
	}, nil
}
