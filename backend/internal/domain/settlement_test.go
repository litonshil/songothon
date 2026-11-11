package domain

import "testing"

func TestCalculateSettlement(t *testing.T) {
	cases := []struct {
		name        string
		in          SettlementInputs
		wantShare   float64
		wantAmount  float64
		wantPercent float64
		wantDistrib float64
	}{
		{
			name:        "profit split by deposit ratio",
			in:          SettlementInputs{MemberDeposits: 25000, StakeDeposits: 100000, NetProfit: 8000},
			wantShare:   2000,
			wantAmount:  27000,
			wantPercent: 25,
			wantDistrib: 8000,
		},
		{
			name:        "loss reduces the payout",
			in:          SettlementInputs{MemberDeposits: 10000, StakeDeposits: 40000, NetProfit: -4000},
			wantShare:   -1000,
			wantAmount:  9000,
			wantPercent: 25,
			wantDistrib: -4000,
		},
		{
			name:        "profit already paid to earlier leavers is excluded",
			in:          SettlementInputs{MemberDeposits: 30000, StakeDeposits: 60000, NetProfit: 9000, ProfitAlreadyPaid: 3000},
			wantShare:   3000,
			wantAmount:  33000,
			wantPercent: 50,
			wantDistrib: 6000,
		},
		{
			name:        "payout never negative",
			in:          SettlementInputs{MemberDeposits: 1000, StakeDeposits: 1000, NetProfit: -5000},
			wantShare:   -5000,
			wantAmount:  0,
			wantPercent: 100,
			wantDistrib: -5000,
		},
		{
			name:        "no deposits gets nothing",
			in:          SettlementInputs{MemberDeposits: 0, StakeDeposits: 50000, NetProfit: 10000},
			wantShare:   0,
			wantAmount:  0,
			wantPercent: 0,
			wantDistrib: 10000,
		},
		{
			name:        "rounds to two decimals",
			in:          SettlementInputs{MemberDeposits: 1000, StakeDeposits: 3000, NetProfit: 100},
			wantShare:   33.33,
			wantAmount:  1033.33,
			wantPercent: 33.33,
			wantDistrib: 100,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := CalculateSettlement(tc.in)
			if got.ProfitShare != tc.wantShare {
				t.Errorf("profit share = %v, want %v", got.ProfitShare, tc.wantShare)
			}
			if got.CalculatedAmount != tc.wantAmount {
				t.Errorf("amount = %v, want %v", got.CalculatedAmount, tc.wantAmount)
			}
			if got.OwnershipPercent != tc.wantPercent {
				t.Errorf("ownership = %v, want %v", got.OwnershipPercent, tc.wantPercent)
			}
			if got.DistributableProfit != tc.wantDistrib {
				t.Errorf("distributable = %v, want %v", got.DistributableProfit, tc.wantDistrib)
			}
		})
	}
}
