-- Down Migration: 000001_init_schema.down.sql

DROP TRIGGER IF EXISTS trg_investments_updated_at ON investments;
DROP TRIGGER IF EXISTS trg_contributions_updated_at ON contributions;
DROP TRIGGER IF EXISTS trg_down_payment_updated_at ON down_payment_schemes;
DROP TRIGGER IF EXISTS trg_share_configs_updated_at ON share_configurations;
DROP TRIGGER IF EXISTS trg_org_members_updated_at ON organization_members;
DROP TRIGGER IF EXISTS trg_organizations_updated_at ON organizations;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;

DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS investments CASCADE;
DROP TABLE IF EXISTS contributions CASCADE;
DROP TABLE IF EXISTS down_payment_schemes CASCADE;
DROP TABLE IF EXISTS share_configurations CASCADE;
DROP TABLE IF EXISTS organization_members CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
