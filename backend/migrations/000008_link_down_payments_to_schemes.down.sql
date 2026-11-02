-- 000008_link_down_payments_to_schemes.down.sql

DROP INDEX IF EXISTS idx_contributions_org_scheme_cycle;
ALTER TABLE contributions DROP COLUMN IF EXISTS scheme_id;
