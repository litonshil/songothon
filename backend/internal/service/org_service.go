package service

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type OrgService struct {
	orgRepo      *postgres.OrgRepository
	userRepo     *postgres.UserRepository
	auditRepo    *postgres.AuditRepository
	notifService *NotificationService
}

func NewOrgService(
	orgRepo *postgres.OrgRepository,
	userRepo *postgres.UserRepository,
	auditRepo *postgres.AuditRepository,
	notifService *NotificationService,
) *OrgService {
	return &OrgService{
		orgRepo:      orgRepo,
		userRepo:     userRepo,
		auditRepo:    auditRepo,
		notifService: notifService,
	}
}

func (s *OrgService) CreateOrganization(ctx context.Context, creatorID uuid.UUID, req *domain.CreateOrganizationRequest) (*domain.Organization, error) {
	slug := strings.ToLower(strings.TrimSpace(req.Slug))
	if slug == "" {
		return nil, errors.New("organization slug is required")
	}

	// Check if slug is already taken
	existing, err := s.orgRepo.GetBySlug(ctx, slug)
	if err != nil {
		return nil, fmt.Errorf("error verifying slug uniqueness: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("organization slug '%s' is already in use. Please choose another", slug)
	}

	currency := strings.ToUpper(strings.TrimSpace(req.Currency))
	if currency == "" {
		currency = "BDT"
	}

	peerVis := true
	if req.AllowPeerFinancialVisibility != nil {
		peerVis = *req.AllowPeerFinancialVisibility
	}
	peerListVis := true
	if req.AllowPeerListVisibility != nil {
		peerListVis = *req.AllowPeerListVisibility
	}
	collectionVis := true
	if req.AllowMemberCollectionVisibility != nil {
		collectionVis = *req.AllowMemberCollectionVisibility
	}

	adminShares := req.InitialAdminShares
	if adminShares <= 0 {
		adminShares = 1
	}

	basePrice := req.BasePricePerShare
	if basePrice <= 0 {
		basePrice = 1000.00
	}

	freq := req.ContributionFrequency
	if freq == "" {
		freq = domain.FrequencyMonthly
	}

	org := &domain.Organization{
		Name:                            strings.TrimSpace(req.Name),
		Slug:                            slug,
		Description:                     strings.TrimSpace(req.Description),
		Currency:                        currency,
		AllowPeerListVisibility:         peerListVis,
		AllowPeerFinancialVisibility:    peerVis,
		AllowMemberCollectionVisibility: collectionVis,
	}

	createdOrg, err := s.orgRepo.Create(ctx, org, creatorID, adminShares, basePrice, freq)
	if err != nil {
		return nil, fmt.Errorf("failed to create organization: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &createdOrg.ID,
		UserID:     &creatorID,
		Action:     "CREATE_ORGANIZATION",
		EntityType: "organizations",
		EntityID:   &createdOrg.ID,
		DetailsJSON: map[string]interface{}{
			"slug":       slug,
			"name":       req.Name,
			"base_price": basePrice,
			"frequency":  freq,
		},
	})

	return createdOrg, nil
}

func (s *OrgService) JoinBySlug(ctx context.Context, userID uuid.UUID, slug string) (*domain.OrganizationMember, error) {
	slug = strings.ToLower(strings.TrimSpace(slug))
	org, err := s.orgRepo.GetBySlug(ctx, slug)
	if err != nil {
		return nil, fmt.Errorf("failed to lookup organization: %w", err)
	}
	if org == nil {
		return nil, errors.New("organization not found with provided slug")
	}

	// Check if already a member
	existingMember, err := s.orgRepo.GetMember(ctx, org.ID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify membership: %w", err)
	}
	if existingMember != nil {
		if existingMember.Status == domain.MemberStatusSuspended || existingMember.Status == domain.MemberStatusRemoved {
			return nil, errors.New("your membership in this organization is suspended")
		}
		return existingMember, nil
	}

	// Joining via slug creates a request that an administrator must approve.
	// The member is created with a default single share.
	member := &domain.OrganizationMember{
		OrgID:       org.ID,
		UserID:      userID,
		Role:        domain.RoleMember,
		SharesCount: 1,
		Status:      domain.MemberStatusPending,
	}

	if err := s.orgRepo.AddMember(ctx, member); err != nil {
		return nil, fmt.Errorf("failed to join organization: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &org.ID,
		UserID:     &userID,
		Action:     "JOIN_ORGANIZATION",
		EntityType: "organization_members",
		EntityID:   &member.ID,
		DetailsJSON: map[string]interface{}{
			"slug": org.Slug,
		},
	})

	return member, nil
}

func (s *OrgService) InviteMember(ctx context.Context, orgID, inviterID uuid.UUID, req *domain.InviteMemberRequest) (*domain.OrgMemberDetail, error) {
	identifier := strings.TrimSpace(req.EmailOrPhone)
	if identifier == "" {
		return nil, errors.New("email or phone number is required")
	}

	// Find user by email or phone
	var targetUser *domain.User
	var err error
	if strings.Contains(identifier, "@") {
		targetUser, err = s.userRepo.GetByEmail(ctx, identifier)
	} else {
		targetUser, err = s.userRepo.GetByPhone(ctx, identifier)
	}

	if err != nil {
		return nil, fmt.Errorf("error finding invited user: %w", err)
	}

	shares := req.SharesCount
	if shares < 0 {
		shares = 1
	}

	if targetUser == nil {
		inv := &domain.OrganizationInvitation{
			OrgID:       orgID,
			Role:        req.Role,
			SharesCount: shares,
			InvitedBy:   &inviterID,
			Status:      "pending",
		}
		if strings.Contains(identifier, "@") {
			email := strings.ToLower(identifier)
			inv.Email = &email
		} else {
			phone := identifier
			inv.Phone = &phone
		}
		if err := s.orgRepo.CreateInvitation(ctx, inv); err != nil {
			return nil, fmt.Errorf("failed to create invitation: %w", err)
		}

		_ = s.auditRepo.Log(ctx, &domain.AuditLog{
			OrgID:      &orgID,
			UserID:     &inviterID,
			Action:     "INVITE_MEMBER_PENDING",
			EntityType: "organization_invitations",
			EntityID:   &inv.ID,
			DetailsJSON: map[string]interface{}{
				"identifier":   identifier,
				"role":         req.Role,
				"shares_count": shares,
			},
		})

		return &domain.OrgMemberDetail{
			ID:          inv.ID,
			OrgID:       orgID,
			Role:        inv.Role,
			SharesCount: inv.SharesCount,
			Status:      domain.MemberStatusInvited,
			JoinedAt:    inv.CreatedAt,
		}, nil
	}

	member := &domain.OrganizationMember{
		OrgID:       orgID,
		UserID:      targetUser.ID,
		Role:        req.Role,
		SharesCount: shares,
		Status:      domain.MemberStatusActive,
	}

	if err := s.orgRepo.AddMember(ctx, member); err != nil {
		return nil, fmt.Errorf("failed to add member to organization: %w", err)
	}

	org, _ := s.orgRepo.GetByID(ctx, orgID)
	orgName := "Songothon Organization"
	if org != nil {
		orgName = org.Name
	}

	// Trigger push notification to invited member
	_ = s.notifService.SendToUser(
		ctx,
		&orgID,
		targetUser.ID,
		"You were added to "+orgName,
		fmt.Sprintf("You have been added as %s with %d share(s).", req.Role, shares),
		"org_invite",
		map[string]string{
			"org_id": orgID.String(),
			"role":   string(req.Role),
		},
	)

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &inviterID,
		Action:     "INVITE_MEMBER",
		EntityType: "organization_members",
		EntityID:   &member.ID,
		DetailsJSON: map[string]interface{}{
			"target_user_id": targetUser.ID.String(),
			"role":           req.Role,
			"shares_count":   shares,
		},
	})

	return &domain.OrgMemberDetail{
		ID:          member.ID,
		OrgID:       orgID,
		UserID:      targetUser.ID,
		FullName:    targetUser.FullName,
		Email:       targetUser.Email,
		Phone:       targetUser.Phone,
		Role:        member.Role,
		SharesCount: member.SharesCount,
		Status:      member.Status,
		JoinedAt:    member.JoinedAt,
	}, nil
}

func (s *OrgService) UpdateMember(ctx context.Context, orgID, updaterID uuid.UUID, memberID uuid.UUID, req *domain.UpdateMemberRequest) error {
	current, err := s.orgRepo.GetMember(ctx, orgID, memberID)
	if err != nil {
		return err
	}
	if current == nil {
		return errors.New("member not found in this organization")
	}

	if req.Status == domain.MemberStatusRemoved {
		return s.RemoveMember(ctx, orgID, updaterID, memberID)
	}

	// Never allow the organization to lose its last administrator.
	if current.Role == domain.RoleOrgAdmin && req.Role != "" && req.Role != domain.RoleOrgAdmin {
		admins, err := s.orgRepo.CountAdmins(ctx, orgID)
		if err != nil {
			return err
		}
		if admins <= 1 {
			return errors.New("at least one organization administrator must remain")
		}
	}
	if current.Role == domain.RoleOrgAdmin && req.Status != "" && req.Status != domain.MemberStatusActive {
		admins, err := s.orgRepo.CountAdmins(ctx, orgID)
		if err != nil {
			return err
		}
		if admins <= 1 {
			return errors.New("at least one organization administrator must remain")
		}
	}

	var role *domain.OrgRole
	if req.Role != "" {
		role = &req.Role
	}
	var status *domain.MemberStatus
	if req.Status != "" {
		status = &req.Status
	}

	if err := s.orgRepo.UpdateMember(ctx, orgID, memberID, role, req.SharesCount, status); err != nil {
		return fmt.Errorf("failed to update member: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &updaterID,
		Action:     "UPDATE_MEMBER",
		EntityType: "organization_members",
		EntityID:   &memberID,
		DetailsJSON: map[string]interface{}{
			"role":         req.Role,
			"shares_count": req.SharesCount,
			"status":       req.Status,
		},
	})

	if req.Role != "" || req.SharesCount != nil || req.Status != "" {
		_ = s.notifService.SendToUser(ctx, &orgID, memberID,
			"Membership updated",
			"Your role, shares or membership status was updated by an administrator.",
			"membership_updated",
			map[string]string{"org_id": orgID.String()},
		)
	}

	return nil
}

func (s *OrgService) RemoveMember(ctx context.Context, orgID, updaterID, memberID uuid.UUID) error {
	current, err := s.orgRepo.GetMember(ctx, orgID, memberID)
	if err != nil {
		return err
	}
	if current == nil {
		return errors.New("member not found in this organization")
	}
	if current.Role == domain.RoleOrgAdmin {
		admins, err := s.orgRepo.CountAdmins(ctx, orgID)
		if err != nil {
			return err
		}
		if admins <= 1 {
			return errors.New("at least one organization administrator must remain")
		}
	}
	if err := s.orgRepo.RemoveMember(ctx, orgID, memberID); err != nil {
		return err
	}
	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &updaterID,
		Action:     "REMOVE_MEMBER",
		EntityType: "organization_members",
		EntityID:   &memberID,
	})
	_ = s.notifService.SendToUser(ctx, &orgID, memberID,
		"Membership removed",
		"You have been removed from the organization by an administrator.",
		"membership_removed",
		map[string]string{"org_id": orgID.String()},
	)
	return nil
}

func (s *OrgService) ListPendingJoinRequests(ctx context.Context, orgID uuid.UUID) ([]domain.PendingJoinRequest, error) {
	return s.orgRepo.ListPendingJoinRequests(ctx, orgID)
}

func (s *OrgService) ApproveJoinRequest(ctx context.Context, orgID, adminID, userID uuid.UUID) error {
	if err := s.orgRepo.ApproveJoinRequest(ctx, orgID, userID); err != nil {
		return err
	}
	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "APPROVE_JOIN_REQUEST",
		EntityType: "organization_members",
		EntityID:   &userID,
	})
	org, _ := s.orgRepo.GetByID(ctx, orgID)
	orgName := "the organization"
	if org != nil {
		orgName = org.Name
	}
	_ = s.notifService.SendToUser(ctx, &orgID, userID,
		"Join request approved",
		fmt.Sprintf("Your request to join %s has been approved. Welcome!", orgName),
		"join_approved",
		map[string]string{"org_id": orgID.String()},
	)
	return nil
}

func (s *OrgService) RejectJoinRequest(ctx context.Context, orgID, adminID, userID uuid.UUID) error {
	if err := s.orgRepo.RejectJoinRequest(ctx, orgID, userID); err != nil {
		return err
	}
	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "REJECT_JOIN_REQUEST",
		EntityType: "organization_members",
		EntityID:   &userID,
	})
	_ = s.notifService.SendToUser(ctx, &orgID, userID,
		"Join request rejected",
		"Your request to join the organization was rejected by an administrator.",
		"join_rejected",
		map[string]string{"org_id": orgID.String()},
	)
	return nil
}

func (s *OrgService) ListInvitations(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationInvitation, error) {
	return s.orgRepo.ListInvitations(ctx, orgID)
}

func (s *OrgService) ListUserOrganizations(ctx context.Context, userID uuid.UUID) ([]domain.UserOrgMembershipResponse, error) {
	return s.orgRepo.ListUserOrganizations(ctx, userID)
}

func (s *OrgService) GetOrganization(ctx context.Context, orgID uuid.UUID) (*domain.Organization, error) {
	return s.orgRepo.GetByID(ctx, orgID)
}

func (s *OrgService) ListMembers(ctx context.Context, orgID uuid.UUID) ([]domain.OrgMemberDetail, error) {
	return s.orgRepo.ListMembers(ctx, orgID)
}

func (s *OrgService) UpdatePrivacy(ctx context.Context, orgID, adminID uuid.UUID, allowList, allowFinancial, allowCollection bool) error {
	if err := s.orgRepo.UpdatePrivacy(ctx, orgID, allowList, allowFinancial, allowCollection); err != nil {
		return fmt.Errorf("failed to update privacy settings: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "UPDATE_PRIVACY_SETTINGS",
		EntityType: "organizations",
		EntityID:   &orgID,
		DetailsJSON: map[string]interface{}{
			"allow_peer_list_visibility":         allowList,
			"allow_peer_financial_visibility":    allowFinancial,
			"allow_member_collection_visibility": allowCollection,
		},
	})

	return nil
}

func (s *OrgService) ConfigureShares(ctx context.Context, orgID, adminID uuid.UUID, req *domain.ConfigureSharesRequest) error {
	sc := &domain.ShareConfiguration{
		OrgID:             orgID,
		BasePricePerShare: req.BasePricePerShare,
		Frequency:         req.Frequency,
		DueDayOfPeriod:    req.DueDayOfPeriod,
	}

	if err := s.orgRepo.CreateShareConfig(ctx, sc); err != nil {
		return fmt.Errorf("failed to update share configuration: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "CONFIGURE_SHARES",
		EntityType: "share_configurations",
		EntityID:   &sc.ID,
		DetailsJSON: map[string]interface{}{
			"base_price": req.BasePricePerShare,
			"frequency":  req.Frequency,
		},
	})

	return nil
}

func (s *OrgService) CreateDownPaymentScheme(ctx context.Context, orgID, adminID uuid.UUID, req *domain.CreateDownPaymentSchemeRequest) error {
	dp := &domain.DownPaymentScheme{
		OrgID:      orgID,
		Title:      req.Title,
		Amount:     req.Amount,
		SchemeType: req.SchemeType,
		Frequency:  req.Frequency,
		StartDate:  req.StartDate,
		DueDate:    req.DueDate,
	}

	if err := s.orgRepo.CreateDownPaymentScheme(ctx, dp); err != nil {
		return fmt.Errorf("failed to create down payment scheme: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "CREATE_DOWN_PAYMENT_SCHEME",
		EntityType: "down_payment_schemes",
		EntityID:   &dp.ID,
		DetailsJSON: map[string]interface{}{
			"title":  req.Title,
			"amount": req.Amount,
		},
	})

	return nil
}

func (s *OrgService) ListDownPaymentSchemes(ctx context.Context, orgID uuid.UUID) ([]domain.DownPaymentScheme, error) {
	return s.orgRepo.ListDownPaymentSchemes(ctx, orgID)
}
