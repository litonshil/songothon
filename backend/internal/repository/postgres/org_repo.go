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

type OrgRepository struct {
	db *DB
}

func NewOrgRepository(db *DB) *OrgRepository {
	return &OrgRepository{db: db}
}

func (r *OrgRepository) Create(
	ctx context.Context,
	org *domain.Organization,
	creatorID uuid.UUID,
	adminShares int,
	basePrice float64,
	freq domain.ContributionFrequency,
) (*domain.Organization, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if org.ID == uuid.Nil {
		org.ID = uuid.New()
	}
	if org.Currency == "" {
		org.Currency = "BDT"
	}
	org.CreatedBy = &creatorID

	// 1. Insert Organization
	orgQuery := `
		INSERT INTO organizations (id, name, slug, description, currency, allow_peer_list_visibility, allow_peer_financial_visibility, allow_member_collection_visibility, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	err = tx.QueryRow(ctx, orgQuery,
		org.ID, org.Name, org.Slug, org.Description, org.Currency, org.AllowPeerListVisibility, org.AllowPeerFinancialVisibility, org.AllowMemberCollectionVisibility, org.CreatedBy,
	).Scan(&org.ID, &org.CreatedAt, &org.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert organization: %w", err)
	}

	// 2. Insert Creator as Org Admin Member
	if adminShares <= 0 {
		adminShares = 1
	}
	memberQuery := `
		INSERT INTO organization_members (id, org_id, user_id, role, shares_count, status, joined_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW())
	`
	_, err = tx.Exec(ctx, memberQuery,
		uuid.New(), org.ID, creatorID, domain.RoleOrgAdmin, adminShares, domain.MemberStatusActive,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert creator as org_admin: %w", err)
	}

	// 3. Insert Initial Share Configuration
	shareQuery := `
		INSERT INTO share_configurations (id, org_id, base_price_per_share, frequency, due_day_of_period, is_active, effective_from, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 10, true, CURRENT_DATE, NOW(), NOW())
	`
	_, err = tx.Exec(ctx, shareQuery,
		uuid.New(), org.ID, basePrice, freq,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert initial share configuration: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit organization creation: %w", err)
	}

	return org, nil
}

func (r *OrgRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error) {
	query := `
		SELECT id, name, slug, COALESCE(description, ''), currency, allow_peer_list_visibility, allow_peer_financial_visibility, allow_member_collection_visibility, created_by, created_at, updated_at
		FROM organizations
		WHERE id = $1 AND deleted_at IS NULL
	`
	var org domain.Organization
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&org.ID, &org.Name, &org.Slug, &org.Description, &org.Currency, &org.AllowPeerListVisibility, &org.AllowPeerFinancialVisibility, &org.AllowMemberCollectionVisibility, &org.CreatedBy, &org.CreatedAt, &org.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch organization by id: %w", err)
	}
	return &org, nil
}

func (r *OrgRepository) GetBySlug(ctx context.Context, slug string) (*domain.Organization, error) {
	query := `
		SELECT id, name, slug, COALESCE(description, ''), currency, allow_peer_list_visibility, allow_peer_financial_visibility, allow_member_collection_visibility, created_by, created_at, updated_at
		FROM organizations
		WHERE LOWER(slug) = LOWER($1) AND deleted_at IS NULL
	`
	var org domain.Organization
	err := r.db.Pool.QueryRow(ctx, query, slug).Scan(
		&org.ID, &org.Name, &org.Slug, &org.Description, &org.Currency, &org.AllowPeerListVisibility, &org.AllowPeerFinancialVisibility, &org.AllowMemberCollectionVisibility, &org.CreatedBy, &org.CreatedAt, &org.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch organization by slug: %w", err)
	}
	return &org, nil
}

func (r *OrgRepository) ListUserOrganizations(ctx context.Context, userID uuid.UUID) ([]domain.UserOrgMembershipResponse, error) {
	query := `
		SELECT 
			o.id, o.name, o.slug, COALESCE(o.description, ''), o.currency, o.allow_peer_list_visibility, o.allow_peer_financial_visibility, o.allow_member_collection_visibility, o.created_by, o.created_at, o.updated_at,
			m.role, m.shares_count, m.status
		FROM organization_members m
		JOIN organizations o ON m.org_id = o.id
		WHERE m.user_id = $1 AND m.deleted_at IS NULL AND m.status NOT IN ('removed') AND o.deleted_at IS NULL
		ORDER BY m.joined_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to list user organizations: %w", err)
	}
	defer rows.Close()

	var result []domain.UserOrgMembershipResponse
	for rows.Next() {
		var item domain.UserOrgMembershipResponse
		err := rows.Scan(
			&item.Organization.ID, &item.Organization.Name, &item.Organization.Slug, &item.Organization.Description, &item.Organization.Currency,
			&item.Organization.AllowPeerListVisibility, &item.Organization.AllowPeerFinancialVisibility, &item.Organization.AllowMemberCollectionVisibility, &item.Organization.CreatedBy, &item.Organization.CreatedAt, &item.Organization.UpdatedAt,
			&item.Role, &item.SharesCount, &item.Status,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user organization row: %w", err)
		}
		result = append(result, item)
	}
	return result, nil
}

func (r *OrgRepository) AddMember(ctx context.Context, m *domain.OrganizationMember) error {
	query := `
		INSERT INTO organization_members (id, org_id, user_id, role, shares_count, status, joined_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW())
		ON CONFLICT (org_id, user_id) 
		DO UPDATE SET 
			role = EXCLUDED.role, 
			shares_count = EXCLUDED.shares_count, 
			status = EXCLUDED.status, 
			deleted_at = NULL, 
			updated_at = NOW()
		RETURNING id, joined_at, created_at, updated_at
	`
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	if m.Status == "" {
		m.Status = domain.MemberStatusActive
	}

	return r.db.Pool.QueryRow(ctx, query,
		m.ID, m.OrgID, m.UserID, m.Role, m.SharesCount, m.Status,
	).Scan(&m.ID, &m.JoinedAt, &m.CreatedAt, &m.UpdatedAt)
}

func (r *OrgRepository) GetMember(ctx context.Context, orgID, userID uuid.UUID) (*domain.OrganizationMember, error) {
	query := `
		SELECT id, org_id, user_id, role, shares_count, status, joined_at, created_at, updated_at
		FROM organization_members
		WHERE org_id = $1 AND user_id = $2 AND deleted_at IS NULL
	`
	var m domain.OrganizationMember
	err := r.db.Pool.QueryRow(ctx, query, orgID, userID).Scan(
		&m.ID, &m.OrgID, &m.UserID, &m.Role, &m.SharesCount, &m.Status, &m.JoinedAt, &m.CreatedAt, &m.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch member: %w", err)
	}
	return &m, nil
}

func (r *OrgRepository) UpdateMember(
	ctx context.Context,
	orgID, userID uuid.UUID,
	role *domain.OrgRole,
	shares *int,
	status *domain.MemberStatus,
) error {
	query := `
		UPDATE organization_members
		SET 
			role = COALESCE($3, role),
			shares_count = COALESCE($4, shares_count),
			status = COALESCE($5, status),
			updated_at = NOW()
		WHERE org_id = $1 AND user_id = $2 AND deleted_at IS NULL
	`
	_, err := r.db.Pool.Exec(ctx, query, orgID, userID, role, shares, status)
	return err
}

func (r *OrgRepository) ListMembers(ctx context.Context, orgID uuid.UUID) ([]domain.OrgMemberDetail, error) {
	query := `
		SELECT 
			m.id, m.org_id, m.user_id, u.full_name, u.email, COALESCE(u.phone, ''),
			m.role, m.shares_count, m.status, m.joined_at,
			COALESCE(
				(SELECT SUM(c.amount) FROM contributions c WHERE c.org_id = m.org_id AND c.user_id = m.user_id AND c.status = 'APPROVED' AND c.deleted_at IS NULL),
				0.0
			) as total_savings
		FROM organization_members m
		JOIN users u ON m.user_id = u.id
		WHERE m.org_id = $1 AND m.status IN ('active', 'invited', 'suspended') AND m.deleted_at IS NULL AND u.deleted_at IS NULL
		ORDER BY m.role ASC, u.full_name ASC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to query members: %w", err)
	}
	defer rows.Close()

	var list []domain.OrgMemberDetail
	for rows.Next() {
		var d domain.OrgMemberDetail
		var savings float64
		err := rows.Scan(
			&d.ID, &d.OrgID, &d.UserID, &d.FullName, &d.Email, &d.Phone,
			&d.Role, &d.SharesCount, &d.Status, &d.JoinedAt, &savings,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan member detail: %w", err)
		}
		d.TotalSavings = &savings
		list = append(list, d)
	}
	return list, nil
}

func (r *OrgRepository) UpdatePrivacy(ctx context.Context, orgID uuid.UUID, allowList, allowFinancial, allowCollection bool) error {
	query := `UPDATE organizations SET allow_peer_list_visibility = $1, allow_peer_financial_visibility = $2, allow_member_collection_visibility = $3, updated_at = NOW() WHERE id = $4`
	_, err := r.db.Pool.Exec(ctx, query, allowList, allowFinancial, allowCollection, orgID)
	return err
}

func (r *OrgRepository) GetActiveShareConfig(ctx context.Context, orgID uuid.UUID) (*domain.ShareConfiguration, error) {
	query := `
		SELECT id, org_id, base_price_per_share, frequency, due_day_of_period, is_active, effective_from, created_at, updated_at
		FROM share_configurations
		WHERE org_id = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT 1
	`
	var sc domain.ShareConfiguration
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(
		&sc.ID, &sc.OrgID, &sc.BasePricePerShare, &sc.Frequency, &sc.DueDayOfPeriod, &sc.IsActive, &sc.EffectiveFrom, &sc.CreatedAt, &sc.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch share config: %w", err)
	}
	return &sc, nil
}

func (r *OrgRepository) CreateShareConfig(ctx context.Context, sc *domain.ShareConfiguration) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Deactivate existing active configs
	_, err = tx.Exec(ctx, `UPDATE share_configurations SET is_active = false, updated_at = NOW() WHERE org_id = $1 AND is_active = true`, sc.OrgID)
	if err != nil {
		return err
	}

	if sc.ID == uuid.Nil {
		sc.ID = uuid.New()
	}
	if sc.DueDayOfPeriod <= 0 {
		sc.DueDayOfPeriod = 10
	}
	sc.IsActive = true
	if sc.EffectiveFrom.IsZero() {
		sc.EffectiveFrom = time.Now()
	}

	query := `
		INSERT INTO share_configurations (id, org_id, base_price_per_share, frequency, due_day_of_period, is_active, effective_from, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	err = tx.QueryRow(ctx, query,
		sc.ID, sc.OrgID, sc.BasePricePerShare, sc.Frequency, sc.DueDayOfPeriod, sc.IsActive, sc.EffectiveFrom,
	).Scan(&sc.CreatedAt, &sc.UpdatedAt)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *OrgRepository) CreateDownPaymentScheme(ctx context.Context, dp *domain.DownPaymentScheme) error {
	if dp.ID == uuid.Nil {
		dp.ID = uuid.New()
	}
	dp.IsActive = true
	query := `
		INSERT INTO down_payment_schemes (id, org_id, title, amount, scheme_type, frequency, start_date, due_date, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7::date, $8::date, $9, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.db.Pool.QueryRow(ctx, query,
		dp.ID, dp.OrgID, dp.Title, dp.Amount, dp.SchemeType, dp.Frequency, dp.StartDate, dp.DueDate, dp.IsActive,
	).Scan(&dp.CreatedAt, &dp.UpdatedAt)
}

func (r *OrgRepository) ListDownPaymentSchemes(ctx context.Context, orgID uuid.UUID) ([]domain.DownPaymentScheme, error) {
	query := `
		SELECT id, org_id, title, amount, scheme_type, frequency,
			TO_CHAR(start_date, 'YYYY-MM-DD'), TO_CHAR(due_date, 'YYYY-MM-DD'), is_active, created_at, updated_at
		FROM down_payment_schemes
		WHERE org_id = $1 AND is_active = true
		ORDER BY created_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var schemes []domain.DownPaymentScheme
	for rows.Next() {
		var s domain.DownPaymentScheme
		err := rows.Scan(
			&s.ID, &s.OrgID, &s.Title, &s.Amount, &s.SchemeType, &s.Frequency, &s.StartDate, &s.DueDate, &s.IsActive, &s.CreatedAt, &s.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		schemes = append(schemes, s)
	}
	return schemes, nil
}

func (r *OrgRepository) ListPendingJoinRequests(ctx context.Context, orgID uuid.UUID) ([]domain.PendingJoinRequest, error) {
	query := `
		SELECT m.id, m.user_id, u.full_name, u.email, COALESCE(u.phone, ''), m.shares_count, m.status, m.joined_at
		FROM organization_members m
		JOIN users u ON m.user_id = u.id
		WHERE m.org_id = $1 AND m.status = 'pending' AND m.deleted_at IS NULL
		ORDER BY m.joined_at ASC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to query pending join requests: %w", err)
	}
	defer rows.Close()

	var list []domain.PendingJoinRequest
	for rows.Next() {
		var item domain.PendingJoinRequest
		if err := rows.Scan(&item.MemberID, &item.UserID, &item.FullName, &item.Email, &item.Phone, &item.SharesCount, &item.Status, &item.RequestedAt); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	return list, nil
}

func (r *OrgRepository) ApproveJoinRequest(ctx context.Context, orgID, userID uuid.UUID) error {
	query := `
		UPDATE organization_members
		SET status = 'active', joined_at = NOW(), updated_at = NOW()
		WHERE org_id = $1 AND user_id = $2 AND status = 'pending' AND deleted_at IS NULL
	`
	res, err := r.db.Pool.Exec(ctx, query, orgID, userID)
	if err != nil {
		return fmt.Errorf("failed to approve join request: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("pending join request not found")
	}
	return nil
}

func (r *OrgRepository) RejectJoinRequest(ctx context.Context, orgID, userID uuid.UUID) error {
	query := `
		UPDATE organization_members
		SET status = 'removed', deleted_at = NOW(), updated_at = NOW()
		WHERE org_id = $1 AND user_id = $2 AND status = 'pending' AND deleted_at IS NULL
	`
	res, err := r.db.Pool.Exec(ctx, query, orgID, userID)
	if err != nil {
		return fmt.Errorf("failed to reject join request: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("pending join request not found")
	}
	return nil
}

func (r *OrgRepository) RemoveMember(ctx context.Context, orgID, userID uuid.UUID) error {
	query := `
		UPDATE organization_members
		SET status = 'removed', deleted_at = NOW(), updated_at = NOW()
		WHERE org_id = $1 AND user_id = $2 AND deleted_at IS NULL
	`
	res, err := r.db.Pool.Exec(ctx, query, orgID, userID)
	if err != nil {
		return fmt.Errorf("failed to remove member: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("member not found")
	}
	return nil
}

func (r *OrgRepository) CountAdmins(ctx context.Context, orgID uuid.UUID) (int, error) {
	query := `
		SELECT COUNT(*) FROM organization_members
		WHERE org_id = $1 AND role = 'org_admin' AND status = 'active' AND deleted_at IS NULL
	`
	var count int
	err := r.db.Pool.QueryRow(ctx, query, orgID).Scan(&count)
	return count, err
}

func (r *OrgRepository) CreateInvitation(ctx context.Context, inv *domain.OrganizationInvitation) error {
	if inv.ID == uuid.Nil {
		inv.ID = uuid.New()
	}
	query := `
		INSERT INTO organization_invitations (id, org_id, email, phone, role, shares_count, invited_by, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.db.Pool.QueryRow(ctx, query,
		inv.ID, inv.OrgID, inv.Email, inv.Phone, inv.Role, inv.SharesCount, inv.InvitedBy,
	).Scan(&inv.CreatedAt, &inv.UpdatedAt)
}

func (r *OrgRepository) ListInvitations(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationInvitation, error) {
	query := `
		SELECT id, org_id, email, phone, role, shares_count, invited_by, status, created_at, updated_at
		FROM organization_invitations
		WHERE org_id = $1 AND status = 'pending'
		ORDER BY created_at DESC
	`
	rows, err := r.db.Pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list invitations: %w", err)
	}
	defer rows.Close()

	var list []domain.OrganizationInvitation
	for rows.Next() {
		var inv domain.OrganizationInvitation
		if err := rows.Scan(&inv.ID, &inv.OrgID, &inv.Email, &inv.Phone, &inv.Role, &inv.SharesCount, &inv.InvitedBy, &inv.Status, &inv.CreatedAt, &inv.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, inv)
	}
	return list, nil
}

// AcceptPendingInvitations links a newly-created user to every organization that
// had invited their email address or phone number before they signed up.
func (r *OrgRepository) AcceptPendingInvitations(ctx context.Context, user *domain.User) error {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin invitation transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	query := `
		SELECT id, org_id, role, shares_count
		FROM organization_invitations
		WHERE status = 'pending'
		  AND ((email IS NOT NULL AND LOWER(email) = LOWER($1))
		       OR (phone IS NOT NULL AND phone = $2))
		FOR UPDATE
	`
	rows, err := tx.Query(ctx, query, user.Email, user.Phone)
	if err != nil {
		return fmt.Errorf("failed to query pending invitations: %w", err)
	}
	type invitation struct {
		id     uuid.UUID
		orgID  uuid.UUID
		role   domain.OrgRole
		shares int
	}
	var invitations []invitation
	for rows.Next() {
		var inv invitation
		if err := rows.Scan(&inv.id, &inv.orgID, &inv.role, &inv.shares); err != nil {
			rows.Close()
			return err
		}
		invitations = append(invitations, inv)
	}
	rows.Close()

	for _, inv := range invitations {
		insert := `
			INSERT INTO organization_members (id, org_id, user_id, role, shares_count, status, joined_at, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, 'active', NOW(), NOW(), NOW())
			ON CONFLICT (org_id, user_id)
			DO UPDATE SET role = EXCLUDED.role, shares_count = EXCLUDED.shares_count,
				status = 'active', deleted_at = NULL, updated_at = NOW()
		`
		if _, err := tx.Exec(ctx, insert, uuid.New(), inv.orgID, user.ID, inv.role, inv.shares); err != nil {
			return fmt.Errorf("failed to accept invitation: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE organization_invitations SET status = 'accepted', updated_at = NOW() WHERE id = $1`, inv.id); err != nil {
			return fmt.Errorf("failed to mark invitation accepted: %w", err)
		}
	}

	return tx.Commit(ctx)
}
