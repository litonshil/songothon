package service

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"songothon/internal/domain"
)

type BulkDepositOptions struct {
	PaymentMethod domain.PaymentMethod
	DryRun        bool
	FileName      string
}

// ErrBulkDepositInvalid is returned (alongside a populated result) when the
// sheet has validation errors; nothing is written in that case.
var ErrBulkDepositInvalid = errors.New("the spreadsheet has errors; fix them and upload again")

// BulkUploadDeposits imports an admin-uploaded deposits sheet. Every deposit
// is recorded as an approved share_installment for the cycle in its column.
//
// The import is all-or-nothing: if any row fails validation no deposits are
// written. Deposits already imported for the same member and cycle are
// reported as skipped, so the same file can be uploaded again safely.
func (s *ContributionService) BulkUploadDeposits(
	ctx context.Context,
	orgID, adminID uuid.UUID,
	file io.Reader,
	opts BulkDepositOptions,
) (*domain.BulkDepositResult, error) {
	if opts.PaymentMethod == "" {
		opts.PaymentMethod = domain.PaymentMethodCash
	}
	switch opts.PaymentMethod {
	case domain.PaymentMethodBKash, domain.PaymentMethodNagad, domain.PaymentMethodRocket,
		domain.PaymentMethodBankTransfer, domain.PaymentMethodCash:
	default:
		return nil, fmt.Errorf("unsupported payment method %q", opts.PaymentMethod)
	}

	cells, cycles, validation, err := ParseBulkDepositSheet(file)
	if err != nil {
		return nil, err
	}

	result := &domain.BulkDepositResult{
		DryRun:        opts.DryRun,
		PaymentMethod: opts.PaymentMethod,
		Cycles:        cycles,
		Errors:        validation,
		Items:         []domain.BulkDepositItem{},
	}

	members, err := s.orgRepo.ListMembers(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to load organization members: %w", err)
	}
	byEmail := make(map[string]domain.OrgMemberDetail, len(members))
	for _, m := range members {
		byEmail[strings.ToLower(strings.TrimSpace(m.Email))] = m
	}

	// Resolve every email once, reporting each unknown/inactive member a single time.
	badEmail := map[string]bool{}
	for _, c := range cells {
		if badEmail[c.Email] {
			continue
		}
		m, ok := byEmail[c.Email]
		switch {
		case !ok:
			badEmail[c.Email] = true
			result.Errors = append(result.Errors, domain.BulkDepositError{
				Row: c.Row, Column: "Email",
				Message: fmt.Sprintf("%s is not a member of this organization", c.Email),
			})
		case m.Status != domain.MemberStatusActive:
			badEmail[c.Email] = true
			result.Errors = append(result.Errors, domain.BulkDepositError{
				Row: c.Row, Column: "Email",
				Message: fmt.Sprintf("%s is %s; deposits can only be recorded for active members", c.Email, m.Status),
			})
		}
	}

	if len(cells) == 0 && len(result.Errors) == 0 {
		result.Errors = append(result.Errors, domain.BulkDepositError{Message: "the sheet contains no deposit amounts"})
	}
	if len(result.Errors) > 0 {
		sort.SliceStable(result.Errors, func(i, j int) bool { return result.Errors[i].Row < result.Errors[j].Row })
		return result, ErrBulkDepositInvalid
	}

	trxIDs := make([]string, len(cells))
	for i, c := range cells {
		trxIDs[i] = domain.BulkDepositTrxID(c.Cycle, byEmail[c.Email].UserID)
	}
	existing, err := s.contribRepo.ExistingTrxIDs(ctx, orgID, trxIDs)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	notes := "Imported from bulk deposit upload"
	if opts.FileName != "" {
		notes = fmt.Sprintf("Imported from bulk deposit upload (%s)", opts.FileName)
	}

	var toCreate []*domain.Contribution
	memberSet := map[uuid.UUID]bool{}
	for i, c := range cells {
		m := byEmail[c.Email]
		item := domain.BulkDepositItem{BulkDepositCell: c, UserID: m.UserID, MemberName: m.FullName}
		memberSet[m.UserID] = true

		if existing[strings.ToLower(trxIDs[i])] {
			item.Status = domain.BulkDepositItemDuplicate
			result.SkippedCount++
			result.SkippedAmount += c.Amount
			result.Items = append(result.Items, item)
			continue
		}

		item.Status = domain.BulkDepositItemWillCreate
		result.CreateCount++
		result.CreateAmount += c.Amount

		if !opts.DryRun {
			reviewedAt := now
			contrib := &domain.Contribution{
				ID:            uuid.New(),
				OrgID:         orgID,
				UserID:        m.UserID,
				Type:          domain.ContributionTypeShareInstallment,
				Amount:        c.Amount,
				PaymentMethod: opts.PaymentMethod,
				TrxID:         trxIDs[i],
				SenderAccount: "bulk-upload",
				TargetCycle:   c.Cycle,
				Status:        domain.ContributionStatusApproved,
				ReviewedBy:    &adminID,
				ReviewedAt:    &reviewedAt,
				PaidAt:        cyclePaidAt(c.Cycle, now),
				Notes:         notes,
			}
			toCreate = append(toCreate, contrib)
			item.Status = domain.BulkDepositItemCreated
			item.ContributionID = &contrib.ID
		}
		result.Items = append(result.Items, item)
	}
	result.MemberCount = len(memberSet)

	if opts.DryRun || len(toCreate) == 0 {
		return result, nil
	}

	if err := s.contribRepo.BulkCreate(ctx, toCreate); err != nil {
		return nil, fmt.Errorf("import failed, no deposits were recorded: %w", err)
	}
	result.Imported = true

	_ = s.auditRepo.Log(ctx, &domain.AuditLog{
		OrgID:      &orgID,
		UserID:     &adminID,
		Action:     "BULK_UPLOAD_DEPOSITS",
		EntityType: "contributions",
		DetailsJSON: map[string]interface{}{
			"file_name":      opts.FileName,
			"payment_method": opts.PaymentMethod,
			"cycles":         cycles,
			"created_count":  result.CreateCount,
			"created_amount": result.CreateAmount,
			"skipped_count":  result.SkippedCount,
			"member_count":   result.MemberCount,
		},
	})

	// Push notifications go out after the response; one summary per member.
	go s.notifyBulkDeposits(context.WithoutCancel(ctx), orgID, toCreate)

	return result, nil
}

func (s *ContributionService) notifyBulkDeposits(ctx context.Context, orgID uuid.UUID, created []*domain.Contribution) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()

	currency := "BDT"
	if org, _ := s.orgRepo.GetByID(ctx, orgID); org != nil && org.Currency != "" {
		currency = org.Currency
	}

	type summary struct {
		count  int
		amount float64
		cycles []string
	}
	perUser := map[uuid.UUID]*summary{}
	for _, c := range created {
		sm := perUser[c.UserID]
		if sm == nil {
			sm = &summary{}
			perUser[c.UserID] = sm
		}
		sm.count++
		sm.amount += c.Amount
		sm.cycles = append(sm.cycles, c.TargetCycle)
	}

	for userID, sm := range perUser {
		sort.Strings(sm.cycles)
		var body string
		if sm.count == 1 {
			body = fmt.Sprintf("A payment of %s %.2f for cycle %s has been recorded and added to your savings.", currency, sm.amount, sm.cycles[0])
		} else {
			body = fmt.Sprintf("%d payments totalling %s %.2f (%s to %s) have been recorded and added to your savings.",
				sm.count, currency, sm.amount, sm.cycles[0], sm.cycles[len(sm.cycles)-1])
		}
		err := s.notifService.SendToUser(ctx, &orgID, userID, "Deposits Recorded 🎉", body, "deposit_approved", map[string]string{
			"org_id": orgID.String(),
			"status": "APPROVED",
			"count":  fmt.Sprintf("%d", sm.count),
			"amount": fmt.Sprintf("%.2f", sm.amount),
		})
		if err != nil {
			log.Printf("bulk deposit: failed to notify user %s: %v", userID, err)
		}
	}
}

// cyclePaidAt dates an imported deposit to the 1st of its cycle month so a
// member's history sorts chronologically; future cycles are capped at now.
// Noon UTC keeps the date on the 1st in every timezone.
func cyclePaidAt(cycle string, now time.Time) time.Time {
	t, err := time.Parse("2006-01", cycle)
	if err != nil {
		return now
	}
	t = t.Add(12 * time.Hour)
	if t.After(now) {
		return now
	}
	return t
}
