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

// SettlementService handles an administrator paying out a member who leaves:
// the member receives their deposits plus their share of the organization's
// net profit (or minus their share of a loss), and their membership ends.
type SettlementService struct {
	settlementRepo *postgres.SettlementRepository
	orgRepo        *postgres.OrgRepository
	contribRepo    *postgres.ContributionRepository
	invRepo        *postgres.InvestmentRepository
	expRepo        *postgres.ExpenseRepository
	incRepo        *postgres.IncomeRepository
	userRepo       *postgres.UserRepository
	auditRepo      *postgres.AuditRepository
	notifService   *NotificationService
}

func NewSettlementService(
	settlementRepo *postgres.SettlementRepository,
	orgRepo *postgres.OrgRepository,
	contribRepo *postgres.ContributionRepository,
	invRepo *postgres.InvestmentRepository,
	expRepo *postgres.ExpenseRepository,
	incRepo *postgres.IncomeRepository,
	userRepo *postgres.UserRepository,
	auditRepo *postgres.AuditRepository,
	notifService *NotificationService,
) *SettlementService {
	return &SettlementService{
		settlementRepo: settlementRepo,
		orgRepo:        orgRepo,
		contribRepo:    contribRepo,
		invRepo:        invRepo,
		expRepo:        expRepo,
		incRepo:        incRepo,
		userRepo:       userRepo,
		auditRepo:      auditRepo,
		notifService:   notifService,
	}
}

// Preview calculates what the member would receive if settled now. It never
// changes anything; CanSettle/BlockReason say whether Settle would succeed.
func (s *SettlementService) Preview(ctx context.Context, org *domain.Organization, adminID, userID uuid.UUID) (*domain.SettlementPreview, *domain.OrganizationMember, error) {
	member, err := s.orgRepo.GetMember(ctx, org.ID, userID)
	if err != nil {
		return nil, nil, err
	}
	if member == nil {
		return nil, nil, errors.New("member not found in this organization")
	}
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, nil, err
	}

	memberDeposits, stakeDeposits, pendingCount, err := s.settlementRepo.GetStakeTotals(ctx, org.ID, userID)
	if err != nil {
		return nil, nil, err
	}
	income, err := s.incRepo.GetTotalIncome(ctx, org.ID)
	if err != nil {
		return nil, nil, err
	}
	expense, err := s.expRepo.GetTotalExpense(ctx, org.ID)
	if err != nil {
		return nil, nil, err
	}
	metrics, err := s.invRepo.GetPortfolioMetrics(ctx, org.ID)
	if err != nil {
		return nil, nil, err
	}
	profitPaid, err := s.settlementRepo.GetProfitAlreadyPaid(ctx, org.ID)
	if err != nil {
		return nil, nil, err
	}
	cash, err := s.contribRepo.GetVaultBalance(ctx, org.ID)
	if err != nil {
		return nil, nil, err
	}

	netProfit := domain.RoundMoney(income - expense + metrics.TotalRealizedReturns + metrics.UnrealizedGainLoss)
	calc := domain.CalculateSettlement(domain.SettlementInputs{
		MemberDeposits:    memberDeposits,
		StakeDeposits:     stakeDeposits,
		NetProfit:         netProfit,
		ProfitAlreadyPaid: profitPaid,
	})

	p := &domain.SettlementPreview{
		UserID:              userID,
		Role:                member.Role,
		Status:              member.Status,
		SharesCount:         member.SharesCount,
		Currency:            org.Currency,
		PendingCount:        pendingCount,
		TotalDeposits:       domain.RoundMoney(memberDeposits),
		OwnershipPercent:    calc.OwnershipPercent,
		ProfitShare:         calc.ProfitShare,
		CalculatedAmount:    calc.CalculatedAmount,
		TotalIncome:         income,
		TotalExpense:        expense,
		RealizedReturns:     metrics.TotalRealizedReturns,
		UnrealizedGainLoss:  metrics.UnrealizedGainLoss,
		OrgNetProfit:        netProfit,
		ProfitAlreadyPaid:   domain.RoundMoney(profitPaid),
		DistributableProfit: calc.DistributableProfit,
		StakeDeposits:       domain.RoundMoney(stakeDeposits),
		AvailableCash:       domain.RoundMoney(cash),
	}
	if user != nil {
		p.FullName = user.FullName
		p.Email = user.Email
	}

	switch {
	case userID == adminID:
		p.BlockReason = "You cannot settle yourself; ask another administrator to settle you, or use Leave Organization"
	case member.Status != domain.MemberStatusActive && member.Status != domain.MemberStatusSuspended:
		p.BlockReason = "Only active or suspended members can be settled"
	case pendingCount > 0:
		p.BlockReason = fmt.Sprintf("This member has %d pending deposit(s); approve or reject them first", pendingCount)
	}
	p.CanSettle = p.BlockReason == ""
	return p, member, nil
}

// Settle pays the member out and ends their membership.
func (s *SettlementService) Settle(ctx context.Context, org *domain.Organization, adminID, userID uuid.UUID, req *domain.SettleMemberRequest) (*domain.MemberSettlement, error) {
	if !validPaymentMethod(req.PaymentMethod) {
		return nil, errors.New("payment method must be one of bkash, nagad, rocket, bank_transfer or cash")
	}
	trxID := strings.TrimSpace(req.TrxID)
	notes := strings.TrimSpace(req.Notes)
	if len(trxID) > 100 {
		return nil, errors.New("transaction ID must be at most 100 characters")
	}

	preview, member, err := s.Preview(ctx, org, adminID, userID)
	if err != nil {
		return nil, err
	}
	if !preview.CanSettle {
		return nil, errors.New(preview.BlockReason)
	}

	final := preview.CalculatedAmount
	if req.FinalAmount != nil {
		final = domain.RoundMoney(*req.FinalAmount)
	}
	if final < 0 {
		return nil, errors.New("settlement amount cannot be negative")
	}
	adjustment := domain.RoundMoney(final - preview.CalculatedAmount)
	if adjustment != 0 && notes == "" {
		return nil, errors.New("add a note explaining why the amount differs from the calculated settlement")
	}
	if final > 0 && req.PaymentMethod != domain.PaymentMethodCash && trxID == "" {
		return nil, errors.New("transaction ID is required for non-cash payouts")
	}

	settlement := &domain.MemberSettlement{
		OrgID:            org.ID,
		UserID:           userID,
		MemberID:         member.ID,
		FullName:         preview.FullName,
		Email:            preview.Email,
		TotalDeposits:    preview.TotalDeposits,
		ProfitShare:      preview.ProfitShare,
		CalculatedAmount: preview.CalculatedAmount,
		Adjustment:       adjustment,
		FinalAmount:      final,
		OrgNetProfit:     preview.OrgNetProfit,
		StakeDeposits:    preview.StakeDeposits,
		PaymentMethod:    req.PaymentMethod,
		TrxID:            trxID,
		Notes:            notes,
		SettledBy:        &adminID,
	}
	if err := s.settlementRepo.Create(ctx, settlement); err != nil {
		return nil, err
	}

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &org.ID,
		UserID:     &adminID,
		Action:     "SETTLE_MEMBER",
		EntityType: "member_settlements",
		EntityID:   &settlement.ID,
		DetailsJSON: map[string]interface{}{
			"member_user_id":    userID.String(),
			"previous_role":     member.Role,
			"total_deposits":    settlement.TotalDeposits,
			"profit_share":      settlement.ProfitShare,
			"calculated_amount": settlement.CalculatedAmount,
			"adjustment":        settlement.Adjustment,
			"final_amount":      settlement.FinalAmount,
			"payment_method":    settlement.PaymentMethod,
			"trx_id":            settlement.TrxID,
		},
	})

	_ = s.notifService.SendToUser(ctx, &org.ID, userID,
		"Settlement completed",
		fmt.Sprintf("Your membership in %s has been settled. %s %.2f has been paid to you via %s.",
			org.Name, org.Currency, settlement.FinalAmount, settlement.PaymentMethod),
		"membership_updated",
		map[string]string{"org_id": org.ID.String(), "settlement_id": settlement.ID.String()},
	)

	return settlement, nil
}

func (s *SettlementService) List(ctx context.Context, orgID uuid.UUID) ([]domain.MemberSettlement, error) {
	return s.settlementRepo.ListByOrg(ctx, orgID)
}

func validPaymentMethod(m domain.PaymentMethod) bool {
	switch m {
	case domain.PaymentMethodBKash, domain.PaymentMethodNagad, domain.PaymentMethodRocket,
		domain.PaymentMethodBankTransfer, domain.PaymentMethodCash:
		return true
	}
	return false
}
