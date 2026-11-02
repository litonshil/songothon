-- 000008_link_down_payments_to_schemes.up.sql

-- A down payment contribution points at its scheme, and target_cycle holds
-- the scheme period it pays for: 'once' (one_time), 'YYYY-Qn' (quarterly) or
-- 'YYYY' (yearly).
ALTER TABLE contributions
    ADD COLUMN IF NOT EXISTS scheme_id UUID REFERENCES down_payment_schemes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_contributions_org_scheme_cycle
    ON contributions(org_id, scheme_id, target_cycle) WHERE scheme_id IS NOT NULL;
