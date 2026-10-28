-- 000003_create_expenses_schema.up.sql

CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'general',
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT NOT NULL DEFAULT '',
    recorded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_expenses_org_date ON expenses(org_id, expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_recorded_by ON expenses(recorded_by);
