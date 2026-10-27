package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
	"songothon/internal/repository/postgres"
)

type ReportService struct {
	orgRepo     *postgres.OrgRepository
	contribRepo *postgres.ContributionRepository
	invRepo     *postgres.InvestmentRepository
	expRepo     *postgres.ExpenseRepository
	incRepo     *postgres.IncomeRepository
}

func NewReportService(
	orgRepo *postgres.OrgRepository,
	contribRepo *postgres.ContributionRepository,
	invRepo *postgres.InvestmentRepository,
	expRepo *postgres.ExpenseRepository,
	incRepo *postgres.IncomeRepository,
) *ReportService {
	return &ReportService{
		orgRepo:     orgRepo,
		contribRepo: contribRepo,
		invRepo:     invRepo,
		expRepo:     expRepo,
		incRepo:     incRepo,
	}
}

func (s *ReportService) GetMemberDashboard(
	ctx context.Context,
	org *domain.Organization,
	member *domain.OrganizationMember,
) (*domain.MemberDashboardData, error) {
	currentCycle := time.Now().Format("2006-01")

	basePrice := 1000.00
	frequency := "monthly"
	dueDay := 10
	if shareConfig, err := s.orgRepo.GetActiveShareConfig(ctx, org.ID); err == nil && shareConfig != nil {
		basePrice = shareConfig.BasePricePerShare
		if shareConfig.Frequency != "" {
			frequency = string(shareConfig.Frequency)
		}
		if shareConfig.DueDayOfPeriod > 0 {
			dueDay = shareConfig.DueDayOfPeriod
		}
	}
	periodicFee := float64(member.SharesCount) * basePrice

	personalSavings, _ := s.contribRepo.GetUserCumulativeDeposits(ctx, org.ID, member.UserID)
	currentStatus, _ := s.contribRepo.GetCurrentCycleStatus(ctx, org.ID, member.UserID, currentCycle)
	isCyclePaid := currentStatus == "Paid"

	vaultBalance, _ := s.contribRepo.GetVaultBalance(ctx, org.ID)
	totalOrgDeposits, _ := s.contribRepo.GetOrgTotalDeposits(ctx, org.ID)
	totalExpense, _ := s.expRepo.GetTotalExpense(ctx, org.ID)
	totalIncome, _ := s.incRepo.GetTotalIncome(ctx, org.ID)
	investedCapital, _ := s.invRepo.GetTotalActiveCapital(ctx, org.ID)
	liquidityReserve := vaultBalance - investedCapital
	if liquidityReserve < 0 {
		liquidityReserve = 0
	}

	activeInvCount := 0
	if metrics, _ := s.invRepo.GetPortfolioMetrics(ctx, org.ID); metrics != nil {
		activeInvCount = metrics.ActiveInvestmentsCount
	}

	members, _ := s.orgRepo.ListMembers(ctx, org.ID)
	var directory []domain.PeerMemberOverview
	activeMemberCount := 0
	for _, m := range members {
		if m.Status != domain.MemberStatusActive {
			continue
		}
		activeMemberCount++
		if !org.AllowPeerListVisibility {
			continue
		}
		overview := domain.PeerMemberOverview{
			UserID:   m.UserID,
			FullName: m.FullName,
			Role:     m.Role,
			JoinedAt: m.JoinedAt,
		}
		if org.AllowPeerFinancialVisibility {
			shares := m.SharesCount
			overview.SharesCount = &shares
			overview.TotalSavings = m.TotalSavings
			statusStr, _ := s.contribRepo.GetCurrentCycleStatus(ctx, org.ID, m.UserID, currentCycle)
			overview.CurrentStatus = &statusStr
		}
		directory = append(directory, overview)
	}

	pendingCount := 0
	if member.Role == domain.RoleOrgAdmin {
		if pending, _ := s.contribRepo.ListPending(ctx, org.ID); pending != nil {
			pendingCount = len(pending)
		}
	}

	downPayments := s.buildDownPaymentStatuses(ctx, org.ID, member.UserID)

	return &domain.MemberDashboardData{
		OrganizationID:               org.ID,
		OrganizationName:             org.Name,
		OrganizationSlug:             org.Slug,
		OrganizationDescription:      org.Description,
		Currency:                     org.Currency,
		AllowPeerListVisibility:      org.AllowPeerListVisibility,
		AllowPeerFinancialVisibility: org.AllowPeerFinancialVisibility,
		CurrentUserRole:              member.Role,
		PendingApprovalsCount:        pendingCount,
		ContributionFrequency:        frequency,
		DueDayOfPeriod:               dueDay,
		PersonalSavings:              personalSavings,
		AssignedShares:               member.SharesCount,
		BasePricePerShare:            basePrice,
		PeriodicFee:                  periodicFee,
		CurrentCycle:                 currentCycle,
		CurrentCycleStatus:           currentStatus,
		IsCurrentCyclePaid:           isCyclePaid,
		TotalOrgDeposits:             totalOrgDeposits,
		TotalExpense:                 totalExpense,
		TotalIncome:                  totalIncome,
		VaultBalance:                 vaultBalance,
		InvestedCapital:              investedCapital,
		LiquidityReserve:             liquidityReserve,
		ActiveInvestmentsCount:       activeInvCount,
		MemberCount:                  activeMemberCount,
		MembersDirectory:             directory,
		DownPayments:                 downPayments,
	}, nil
}

func (s *ReportService) buildDownPaymentStatuses(ctx context.Context, orgID, userID uuid.UUID) []domain.MemberDownPaymentStatus {
	schemes, err := s.orgRepo.ListDownPaymentSchemes(ctx, orgID)
	if err != nil {
		return nil
	}
	result := make([]domain.MemberDownPaymentStatus, 0, len(schemes))
	for _, scheme := range schemes {
		paid, pending, _ := s.contribRepo.GetMemberTargetTotals(ctx, orgID, userID, domain.ContributionTypeDownPayment, scheme.ID.String())
		status := "Unpaid"
		if paid > 0 {
			status = "Paid"
		} else if pending > 0 {
			status = "Pending"
		}
		result = append(result, domain.MemberDownPaymentStatus{
			SchemeID:      scheme.ID,
			Title:         scheme.Title,
			Amount:        scheme.Amount,
			Frequency:     scheme.Frequency,
			StartDate:     scheme.StartDate,
			DueDate:       scheme.DueDate,
			Status:        status,
			PaidAmount:    paid,
			PendingAmount: pending,
		})
	}
	return result
}

func (s *ReportService) GetAdminDashboard(
	ctx context.Context,
	org *domain.Organization,
) (*domain.AdminDashboardData, error) {
	currentCycle := time.Now().Format("2006-01")

	vaultBalance, _ := s.contribRepo.GetVaultBalance(ctx, org.ID)
	totalDeposits, _ := s.contribRepo.GetOrgTotalDeposits(ctx, org.ID)
	totalExpense, _ := s.expRepo.GetTotalExpense(ctx, org.ID)
	totalIncome, _ := s.incRepo.GetTotalIncome(ctx, org.ID)
	investedCapital, _ := s.invRepo.GetTotalActiveCapital(ctx, org.ID)
	liquidityReserve := vaultBalance - investedCapital
	if liquidityReserve < 0 {
		liquidityReserve = 0
	}

	expected, collected, rate, _ := s.contribRepo.GetCycleStats(ctx, org.ID, currentCycle)
	pending, _ := s.contribRepo.ListPending(ctx, org.ID)
	joinRequests, _ := s.orgRepo.ListPendingJoinRequests(ctx, org.ID)

	metrics, err := s.invRepo.GetPortfolioMetrics(ctx, org.ID)
	if err != nil || metrics == nil {
		metrics = &domain.PortfolioMetrics{}
	}

	members, _ := s.orgRepo.ListMembers(ctx, org.ID)
	var collection []domain.MemberCollectionStatus
	memberCount := 0
	if shareConfig, err := s.orgRepo.GetActiveShareConfig(ctx, org.ID); err == nil && shareConfig != nil {
		for _, m := range members {
			if m.Status != domain.MemberStatusActive {
				continue
			}
			memberCount++
			approved, pendingAmount, _ := s.contribRepo.GetMemberCycleTotals(ctx, org.ID, m.UserID, currentCycle)
			status := "Unpaid"
			if approved > 0 {
				status = "Paid"
			} else if pendingAmount > 0 {
				status = "Pending"
			}
			collection = append(collection, domain.MemberCollectionStatus{
				UserID:         m.UserID,
				FullName:       m.FullName,
				SharesCount:    m.SharesCount,
				ExpectedAmount: float64(m.SharesCount) * shareConfig.BasePricePerShare,
				PaidAmount:     approved,
				PendingAmount:  pendingAmount,
				Status:         status,
			})
		}
	}

	return &domain.AdminDashboardData{
		OrganizationID:           org.ID,
		OrganizationName:         org.Name,
		OrganizationSlug:         org.Slug,
		Currency:                 org.Currency,
		TotalDeposits:            totalDeposits,
		TotalExpense:             totalExpense,
		TotalIncome:              totalIncome,
		TotalVaultBalance:        vaultBalance,
		TotalInvestedCapital:     investedCapital,
		AvailableLiquidity:       liquidityReserve,
		CurrentCycle:             currentCycle,
		CycleCollectionRate:      rate,
		TotalExpectedForCycle:    expected,
		TotalCollectedForCycle:   collected,
		PendingApprovalsCount:    len(pending),
		PendingJoinRequestsCount: len(joinRequests),
		MemberCount:              memberCount,
		PendingDeposits:          pending,
		PendingJoinRequests:      joinRequests,
		CollectionSummary:        collection,
		PortfolioMetrics:         *metrics,
		Members:                  members,
	}, nil
}
