-- 000004_create_incomes_schema.up.sql

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions
    ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'income', 'other'));

CREATE TABLE IF NOT EXISTS incomes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'general',
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    income_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT NOT NULL DEFAULT '',
    recorded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_incomes_org_date ON incomes(org_id, income_date DESC);
CREATE INDEX IF NOT EXISTS idx_incomes_recorded_by ON incomes(recorded_by);
