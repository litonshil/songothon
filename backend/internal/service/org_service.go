package service

import (
	"context"
	"errors"
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"

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

// orgSlugPattern allows a single word made of lowercase letters, digits,
// hyphens and underscores (no spaces or other characters).
var orgSlugPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]*[a-z0-9]$`)

func (s *OrgService) CreateOrganization(ctx context.Context, creatorID uuid.UUID, req *domain.CreateOrganizationRequest) (*domain.Organization, error) {
	slug := strings.ToLower(strings.TrimSpace(req.Slug))
	if slug == "" {
		return nil, errors.New("organization slug is required")
	}
	if len(slug) < 6 || len(slug) > 20 {
		return nil, errors.New("organization slug must be between 6 and 20 characters")
	}
	if !orgSlugPattern.MatchString(slug) {
		return nil, errors.New("organization slug must be a single word using only letters, numbers, hyphens or underscores")
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
		// A member who left may ask to rejoin; that goes through approval again.
		if existingMember.Status != domain.MemberStatusLeft {
			return existingMember, nil
		}
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
	if current.Status == domain.MemberStatusLeft {
		return errors.New("this member has left the organization; they must request to join again")
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

// RenameOrganization changes the organization's display name (and optionally its
// description). The slug is unchanged so join codes stay valid.
func (s *OrgService) RenameOrganization(ctx context.Context, orgID, adminID uuid.UUID, req *domain.RenameOrganizationRequest) (*domain.Organization, error) {
	name := strings.TrimSpace(req.Name)
	if len(name) < 2 || len(name) > 200 {
		return nil, errors.New("organization name must be between 2 and 200 characters")
	}
	var description *string
	if req.Description != nil {
		d := strings.TrimSpace(*req.Description)
		description = &d
	}

	before, err := s.orgRepo.GetByID(ctx, orgID)
	if err != nil {
		return nil, err
	}
	if before == nil {
		return nil, errors.New("organization not found")
	}

	if err := s.orgRepo.UpdateDetails(ctx, orgID, name, description); err != nil {
		return nil, err
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "RENAME_ORGANIZATION",
		EntityType: "organizations",
		EntityID:   &orgID,
		DetailsJSON: map[string]interface{}{
			"old_name":    before.Name,
			"new_name":    name,
			"description": description,
		},
	})

	return s.orgRepo.GetByID(ctx, orgID)
}

// LeaveOrganization lets any member (administrators included) leave. Nothing is
// deleted: the membership is marked 'left' and all history stays intact. If the
// leaver is the last active administrator and other active members remain, a
// successor must be named and is promoted to administrator.
func (s *OrgService) LeaveOrganization(ctx context.Context, orgID, userID uuid.UUID, req *domain.LeaveOrganizationRequest) error {
	current, err := s.orgRepo.GetMember(ctx, orgID, userID)
	if err != nil {
		return err
	}
	if current == nil || (current.Status != domain.MemberStatusActive && current.Status != domain.MemberStatusSuspended) {
		return errors.New("you are not an active member of this organization")
	}

	var successor *uuid.UUID
	if req != nil && req.SuccessorUserID != nil && *req.SuccessorUserID != uuid.Nil {
		if *req.SuccessorUserID == userID {
			return errors.New("you cannot choose yourself as the successor")
		}
		successor = req.SuccessorUserID
	}

	if current.Role == domain.RoleOrgAdmin && current.Status == domain.MemberStatusActive && successor == nil {
		admins, err := s.orgRepo.CountAdmins(ctx, orgID)
		if err != nil {
			return err
		}
		if admins <= 1 {
			others, err := s.orgRepo.CountActiveMembersExcept(ctx, orgID, userID)
			if err != nil {
				return err
			}
			if others > 0 {
				return errors.New("you are the only administrator; choose a member to become administrator before leaving")
			}
		}
	}

	if err := s.orgRepo.LeaveOrganization(ctx, orgID, userID, successor); err != nil {
		return err
	}

	details := map[string]interface{}{"previous_role": current.Role}
	if successor != nil {
		details["successor_user_id"] = successor.String()
	}
	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:       &orgID,
		UserID:      &userID,
		Action:      "LEAVE_ORGANIZATION",
		EntityType:  "organization_members",
		EntityID:    &current.ID,
		DetailsJSON: details,
	})

	org, _ := s.orgRepo.GetByID(ctx, orgID)
	orgName := "the organization"
	if org != nil {
		orgName = org.Name
	}

	if successor != nil {
		_ = s.notifService.SendToUser(ctx, &orgID, *successor,
			"You are now an administrator",
			fmt.Sprintf("You have been made an administrator of %s.", orgName),
			"membership_updated",
			map[string]string{"org_id": orgID.String()},
		)
	}

	leaverName := "A member"
	if u, err := s.userRepo.GetByID(ctx, userID); err == nil && u != nil && u.FullName != "" {
		leaverName = u.FullName
	}
	if adminIDs, err := s.orgRepo.ListActiveAdminIDs(ctx, orgID); err == nil && len(adminIDs) > 0 {
		_ = s.notifService.SendToMembers(ctx, orgID, adminIDs,
			"Member left",
			fmt.Sprintf("%s has left %s.", leaverName, orgName),
		)
	}

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

func (s *OrgService) CreateDownPaymentScheme(ctx context.Context, orgID, adminID uuid.UUID, req *domain.CreateDownPaymentSchemeRequest) (*domain.DownPaymentScheme, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errors.New("scheme title is required")
	}
	if req.Amount <= 0 {
		return nil, errors.New("amount must be greater than zero")
	}
	switch req.SchemeType {
	case "mandatory", "optional":
	case "":
		req.SchemeType = "mandatory"
	default:
		return nil, errors.New("scheme type must be mandatory or optional")
	}
	switch req.Frequency {
	case domain.SchemeFrequencyOneTime, domain.SchemeFrequencyQuarterly, domain.SchemeFrequencyYearly:
	default:
		return nil, errors.New("frequency must be one_time, quarterly or yearly")
	}
	startDate, err := optionalDate(req.StartDate, "start date")
	if err != nil {
		return nil, err
	}
	dueDate, err := optionalDate(req.DueDate, "due date")
	if err != nil {
		return nil, err
	}
	if startDate == nil {
		today := time.Now().Format("2006-01-02")
		startDate = &today
	}
	if dueDate != nil && *dueDate < *startDate {
		return nil, errors.New("due date cannot be before the start date")
	}

	dp := &domain.DownPaymentScheme{
		OrgID:      orgID,
		Title:      title,
		Amount:     req.Amount,
		SchemeType: req.SchemeType,
		Frequency:  req.Frequency,
		StartDate:  startDate,
		DueDate:    dueDate,
	}

	if err := s.orgRepo.CreateDownPaymentScheme(ctx, dp); err != nil {
		return nil, fmt.Errorf("failed to create down payment scheme: %w", err)
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "CREATE_DOWN_PAYMENT_SCHEME",
		EntityType: "down_payment_schemes",
		EntityID:   &dp.ID,
		DetailsJSON: map[string]interface{}{
			"title":       title,
			"amount":      req.Amount,
			"frequency":   req.Frequency,
			"scheme_type": req.SchemeType,
			"start_date":  *startDate,
		},
	})

	schemes := []domain.DownPaymentScheme{*dp}
	decorateSchemes(schemes, time.Now())
	created := &schemes[0]

	if created.SchemeType == "mandatory" {
		go s.announceScheme(context.WithoutCancel(ctx), orgID, *created)
	}
	return created, nil
}

// announceScheme tells every active member about a new mandatory scheme.
func (s *OrgService) announceScheme(ctx context.Context, orgID uuid.UUID, scheme domain.DownPaymentScheme) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()

	members, err := s.orgRepo.ListMembers(ctx, orgID)
	if err != nil {
		log.Printf("announce scheme %s: %v", scheme.ID, err)
		return
	}
	var userIDs []uuid.UUID
	for _, m := range members {
		if m.Status == domain.MemberStatusActive {
			userIDs = append(userIDs, m.UserID)
		}
	}
	if len(userIDs) == 0 {
		return
	}

	currency := "BDT"
	if org, _ := s.orgRepo.GetByID(ctx, orgID); org != nil && org.Currency != "" {
		currency = org.Currency
	}
	cur := scheme.CurrentPeriod
	every := map[string]string{
		domain.SchemeFrequencyQuarterly: " every quarter",
		domain.SchemeFrequencyYearly:    " every year",
	}[scheme.Frequency]
	body := fmt.Sprintf("New down payment \"%s\": %s %.2f per member%s. Payment for %s is due by %s.",
		scheme.Title, currency, scheme.Amount, every, cur.Label, cur.DueDate)
	if scheme.Frequency == domain.SchemeFrequencyOneTime {
		body = fmt.Sprintf("New down payment \"%s\": %s %.2f per member, due by %s.",
			scheme.Title, currency, scheme.Amount, cur.DueDate)
	}
	if err := s.notifService.SendToMembers(ctx, orgID, userIDs, "New Down Payment 📢", body); err != nil {
		log.Printf("announce scheme %s: %v", scheme.ID, err)
	}
}

func optionalDate(v *string, field string) (*string, error) {
	if v == nil || strings.TrimSpace(*v) == "" {
		return nil, nil
	}
	d := strings.TrimSpace(*v)
	if _, err := time.Parse("2006-01-02", d); err != nil {
		return nil, fmt.Errorf("%s must be in YYYY-MM-DD format", field)
	}
	return &d, nil
}

func (s *OrgService) ListDownPaymentSchemes(ctx context.Context, orgID uuid.UUID) ([]domain.DownPaymentScheme, error) {
	schemes, err := s.orgRepo.ListDownPaymentSchemes(ctx, orgID)
	if err != nil {
		return nil, err
	}
	if schemes == nil {
		schemes = []domain.DownPaymentScheme{}
	}
	decorateSchemes(schemes, time.Now())
	return schemes, nil
}
