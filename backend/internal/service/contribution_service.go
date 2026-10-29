package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type ContributionService struct {
	contribRepo  *postgres.ContributionRepository
	orgRepo      *postgres.OrgRepository
	auditRepo    *postgres.AuditRepository
	notifService *NotificationService
}

func NewContributionService(
	contribRepo *postgres.ContributionRepository,
	orgRepo *postgres.OrgRepository,
	auditRepo *postgres.AuditRepository,
	notifService *NotificationService,
) *ContributionService {
	return &ContributionService{
		contribRepo:  contribRepo,
		orgRepo:      orgRepo,
		auditRepo:    auditRepo,
		notifService: notifService,
	}
}

func (s *ContributionService) SubmitDeposit(
	ctx context.Context,
	orgID, actorID uuid.UUID,
	isAdmin bool,
	req *domain.SubmitDepositRequest,
) (*domain.Contribution, error) {
	targetUserID := actorID

	// Organization admins may submit a deposit on behalf of another member.
	if req.UserID != nil && *req.UserID != uuid.Nil && *req.UserID != actorID {
		if !isAdmin {
			return nil, errors.New("only organization admins can submit a deposit on behalf of another member")
		}

		member, err := s.orgRepo.GetMember(ctx, orgID, *req.UserID)
		if err != nil {
			return nil, fmt.Errorf("failed to verify member: %w", err)
		}
		if member == nil {
			return nil, errors.New("selected member does not belong to this organization")
		}
		if member.Status != domain.MemberStatusActive {
			return nil, errors.New("deposits can only be submitted for active members")
		}

		targetUserID = *req.UserID
	}

	trxID := strings.TrimSpace(req.TrxID)
	if trxID == "" {
		return nil, errors.New("transaction ID (trx_id) is required")
	}

	senderAccount := strings.TrimSpace(req.SenderAccount)
	if senderAccount == "" {
		return nil, errors.New("sender account/phone number is required")
	}

	if req.Amount <= 0 {
		return nil, errors.New("deposit amount must be greater than zero")
	}

	targetCycle := strings.TrimSpace(req.TargetCycle)
	if targetCycle == "" {
		return nil, errors.New("target deposit cycle is required")
	}

	// Deposits recorded by an organization admin need no further review.
	contrib := &domain.Contribution{
		OrgID:         orgID,
		UserID:        targetUserID,
		Type:          req.Type,
		Amount:        req.Amount,
		PaymentMethod: req.PaymentMethod,
		TrxID:         trxID,
		SenderAccount: senderAccount,
		ReceiptURL:    req.ReceiptURL,
		TargetCycle:   targetCycle,
		Status:        domain.ContributionStatusPending,
		Notes:         req.Notes,
	}
	if isAdmin {
		now := time.Now()
		contrib.Status = domain.ContributionStatusApproved
		contrib.ReviewedBy = &actorID
		contrib.ReviewedAt = &now
	}

	if err := s.contribRepo.Create(ctx, contrib); err != nil {
		return nil, err
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &actorID,
		Action:     "SUBMIT_DEPOSIT",
		EntityType: "contributions",
		EntityID:   &contrib.ID,
		DetailsJSON: map[string]interface{}{
			"amount":         req.Amount,
			"trx_id":         trxID,
			"target_cycle":   targetCycle,
			"payment_method": req.PaymentMethod,
			"member_id":      targetUserID.String(),
			"submitted_by":   actorID.String(),
			"on_behalf":      targetUserID != actorID,
			"auto_approved":  isAdmin,
		},
	})

	if isAdmin && targetUserID != actorID {
		org, _ := s.orgRepo.GetByID(ctx, orgID)
		currency := "BDT"
		if org != nil && org.Currency != "" {
			currency = org.Currency
		}

		title := "Deposit Approved! 🎉"
		body := fmt.Sprintf("A payment of %s %.2f for cycle %s has been recorded and added to your savings.", currency, contrib.Amount, contrib.TargetCycle)
		_ = s.notifService.SendToUser(ctx, &orgID, targetUserID, title, body, "deposit_approved", map[string]string{
			"org_id":          orgID.String(),
			"contribution_id": contrib.ID.String(),
			"status":          "APPROVED",
			"amount":          fmt.Sprintf("%.2f", contrib.Amount),
			"cycle":           contrib.TargetCycle,
		})
	}

	return contrib, nil
}

func (s *ContributionService) ListPending(ctx context.Context, orgID uuid.UUID) ([]domain.ContributionDetail, error) {
	return s.contribRepo.ListPending(ctx, orgID)
}

func (s *ContributionService) ListContributions(ctx context.Context, orgID uuid.UUID, cycle, status string) ([]domain.ContributionDetail, error) {
	return s.contribRepo.ListByOrg(ctx, orgID, cycle, status)
}

func (s *ContributionService) ListUserContributions(ctx context.Context, orgID, userID uuid.UUID) ([]domain.Contribution, error) {
	return s.contribRepo.ListByUser(ctx, orgID, userID)
}

func (s *ContributionService) ApproveDeposit(ctx context.Context, orgID, contribID, reviewerID uuid.UUID) (*domain.ContributionDetail, error) {
	approved, err := s.contribRepo.ApproveDeposit(ctx, contribID, reviewerID)
	if err != nil {
		return nil, err
	}

	org, _ := s.orgRepo.GetByID(ctx, orgID)
	currency := "BDT"
	if org != nil && org.Currency != "" {
		currency = org.Currency
	}

	// Trigger automated FCM push notification to the member
	title := "Deposit Approved! 🎉"
	body := fmt.Sprintf("Your payment of %s %.2f for cycle %s has been verified and added to your savings.", currency, approved.Amount, approved.TargetCycle)
	_ = s.notifService.SendToUser(ctx, &orgID, approved.UserID, title, body, "deposit_approved", map[string]string{
		"org_id":          orgID.String(),
		"contribution_id": approved.ID.String(),
		"status":          "APPROVED",
		"amount":          fmt.Sprintf("%.2f", approved.Amount),
		"cycle":           approved.TargetCycle,
	})

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &reviewerID,
		Action:     "APPROVE_DEPOSIT",
		EntityType: "contributions",
		EntityID:   &contribID,
		DetailsJSON: map[string]interface{}{
			"amount":       approved.Amount,
			"member_id":    approved.UserID.String(),
			"target_cycle": approved.TargetCycle,
		},
	})

	return approved, nil
}

func (s *ContributionService) RejectDeposit(
	ctx context.Context,
	orgID, contribID, reviewerID uuid.UUID,
	req *domain.ReviewDepositRequest,
) (*domain.ContributionDetail, error) {
	reason := strings.TrimSpace(req.RejectionReason)
	if reason == "" {
		reason = "Transaction verification failed or TrxID could not be matched"
	}

	rejected, err := s.contribRepo.RejectDeposit(ctx, contribID, reviewerID, reason)
	if err != nil {
		return nil, err
	}

	// Trigger automated FCM push notification to the member
	title := "Deposit Verification Notice ⚠️"
	body := fmt.Sprintf("Your deposit of %.2f for cycle %s was rejected. Reason: %s", rejected.Amount, rejected.TargetCycle, reason)
	_ = s.notifService.SendToUser(ctx, &orgID, rejected.UserID, title, body, "deposit_rejected", map[string]string{
		"org_id":          orgID.String(),
		"contribution_id": rejected.ID.String(),
		"status":          "REJECTED",
		"reason":          reason,
		"cycle":           rejected.TargetCycle,
	})

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &reviewerID,
		Action:     "REJECT_DEPOSIT",
		EntityType: "contributions",
		EntityID:   &contribID,
		DetailsJSON: map[string]interface{}{
			"amount":    rejected.Amount,
			"member_id": rejected.UserID.String(),
			"reason":    reason,
		},
	})

	return rejected, nil
}
