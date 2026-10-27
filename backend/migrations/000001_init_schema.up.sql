-- Up Migration: 000001_init_schema.up.sql
-- Multi-tenant schema for Songothon Community Savings, Share, and Investment Management

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Generic Updated At Trigger Function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(50) UNIQUE,
    fcm_token VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending', 'deactivated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- Upgrade existing users table if present from previous schemas
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- 2. Organizations Table (Multi-tenant Root)
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    currency VARCHAR(10) NOT NULL DEFAULT 'BDT',
    allow_peer_financial_visibility BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_organizations_slug ON organizations(slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_organizations_created_by ON organizations(created_by);

-- 3. Organization Members (Join Table with Roles and Share Ownership)
CREATE TABLE IF NOT EXISTS organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (role IN ('org_admin', 'member')),
    shares_count INT NOT NULL DEFAULT 1 CHECK (shares_count >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'suspended')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_org_user UNIQUE (org_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_members_org_id ON organization_members(org_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON organization_members(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_org_members_role ON organization_members(role);

-- 4. Share Configurations (Pricing and Contribution Cadence)
CREATE TABLE IF NOT EXISTS share_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    base_price_per_share NUMERIC(15, 2) NOT NULL CHECK (base_price_per_share > 0),
    frequency VARCHAR(20) NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('weekly', 'monthly', 'yearly')),
    due_day_of_period INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT true,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_share_configs_org_active ON share_configurations(org_id, is_active);

-- 5. Down Payment Schemes (Lump-sum & Capital Calls)
CREATE TABLE IF NOT EXISTS down_payment_schemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    scheme_type VARCHAR(20) NOT NULL DEFAULT 'mandatory' CHECK (scheme_type IN ('mandatory', 'optional')),
    frequency VARCHAR(20) NOT NULL DEFAULT 'one_time' CHECK (frequency IN ('one_time', 'quarterly', 'yearly')),
    due_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_down_payment_org_active ON down_payment_schemes(org_id, is_active);

-- Cleanly drop legacy prototype tables if they lack multi-tenant columns
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'contributions' 
        AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'contributions' AND column_name = 'org_id'
    ) THEN
        DROP TABLE IF EXISTS transactions CASCADE;
        DROP TABLE IF EXISTS contributions CASCADE;
        DROP TABLE IF EXISTS contribution_periods CASCADE;
        DROP TABLE IF EXISTS investments CASCADE;
    END IF;
END $$;

-- 6. Contributions (Member Deposits with Approval Workflow)
CREATE TABLE IF NOT EXISTS contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(30) NOT NULL DEFAULT 'share_installment' CHECK (type IN ('share_installment', 'down_payment', 'ad_hoc')),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('bkash', 'nagad', 'rocket', 'bank_transfer', 'cash')),
    trx_id VARCHAR(100) NOT NULL,
    sender_account VARCHAR(100) NOT NULL,
    receipt_url TEXT,
    target_cycle VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_contributions_org_status ON contributions(org_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contributions_org_user ON contributions(org_id, user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contributions_trx_id ON contributions(org_id, trx_id);
CREATE INDEX IF NOT EXISTS idx_contributions_target_cycle ON contributions(target_cycle);

-- 7. Investments (External Capital Deployments)
CREATE TABLE IF NOT EXISTS investments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    invested_capital NUMERIC(15, 2) NOT NULL CHECK (invested_capital > 0),
    current_valuation NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    expected_roi NUMERIC(6, 2) NOT NULL DEFAULT 0.00,
    realized_returns NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    tenure VARCHAR(100) NOT NULL DEFAULT '',
    notes TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'MATURED', 'LIQUIDATED')),
    investment_date DATE NOT NULL,
    maturity_date DATE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_investments_org_status ON investments(org_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_investments_category ON investments(category);

-- 8. Notifications (FCM and In-App Alerts)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'deposit_update',
    payload_json JSONB DEFAULT '{}',
    is_read BOOLEAN NOT NULL DEFAULT false,
    fcm_message_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- 9. Audit Logs (Compliance & Ledger Immutability)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    ip_address VARCHAR(45),
    details_json JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_org_action ON audit_logs(org_id, action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

-- 10. Financial Ledger / Transactions (Vault inflow/outflow audit)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    type VARCHAR(30) NOT NULL CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'other')),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    flow VARCHAR(10) NOT NULL CHECK (flow IN ('inflow', 'outflow')),
    reference_table VARCHAR(50),
    reference_id UUID,
    recorded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_transactions_org_flow ON transactions(org_id, flow);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Attach update triggers
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_organizations_updated_at ON organizations;
CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_org_members_updated_at ON organization_members;
CREATE TRIGGER trg_org_members_updated_at BEFORE UPDATE ON organization_members FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_share_configs_updated_at ON share_configurations;
CREATE TRIGGER trg_share_configs_updated_at BEFORE UPDATE ON share_configurations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_down_payment_updated_at ON down_payment_schemes;
CREATE TRIGGER trg_down_payment_updated_at BEFORE UPDATE ON down_payment_schemes FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_contributions_updated_at ON contributions;
CREATE TRIGGER trg_contributions_updated_at BEFORE UPDATE ON contributions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS trg_investments_updated_at ON investments;
CREATE TRIGGER trg_investments_updated_at BEFORE UPDATE ON investments FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
