-- 000010_create_member_settlements.up.sql

-- A settlement pays a departing member their deposits plus (or minus) their
-- share of the organization's net profit, records the payout as a ledger
-- outflow and marks the membership 'left'. The calculated figures are frozen
-- here so later changes to the books never rewrite a past settlement.
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions
    ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'income', 'settlement', 'other'));

CREATE TABLE IF NOT EXISTS member_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    member_id UUID NOT NULL REFERENCES organization_members(id) ON DELETE RESTRICT,
    total_deposits NUMERIC(15, 2) NOT NULL CHECK (total_deposits >= 0),
    profit_share NUMERIC(15, 2) NOT NULL,          -- negative when the org is at a loss
    calculated_amount NUMERIC(15, 2) NOT NULL CHECK (calculated_amount >= 0),
    adjustment NUMERIC(15, 2) NOT NULL DEFAULT 0,  -- final_amount - calculated_amount
    final_amount NUMERIC(15, 2) NOT NULL CHECK (final_amount >= 0),
    org_net_profit NUMERIC(15, 2) NOT NULL,        -- snapshot used for the calculation
    stake_deposits NUMERIC(15, 2) NOT NULL,        -- snapshot of all stakeholders' deposits
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('bkash', 'nagad', 'rocket', 'bank_transfer', 'cash')),
    trx_id VARCHAR(100) NOT NULL DEFAULT '',
    notes TEXT NOT NULL DEFAULT '',
    settled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    settled_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_member_settlements_org_settled ON member_settlements(org_id, settled_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_settlements_org_user ON member_settlements(org_id, user_id);
CREATE INDEX IF NOT EXISTS idx_member_settlements_settled_by ON member_settlements(settled_by);
