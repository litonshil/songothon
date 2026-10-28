-- 000001_create_initial_schema.up.sql

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(50) UNIQUE,
    fcm_token VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending', 'deactivated')), -- 'active', 'pending', 'deactivated'
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    currency VARCHAR(10) NOT NULL DEFAULT 'BDT',
    allow_peer_financial_visibility BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (role IN ('org_admin', 'member')), -- 'org_admin', 'member'
    shares_count INT NOT NULL DEFAULT 1 CHECK (shares_count >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'suspended')), -- 'active', 'invited', 'suspended'
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_org_user UNIQUE (org_id, user_id)
);

CREATE TABLE IF NOT EXISTS share_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    base_price_per_share NUMERIC(15, 2) NOT NULL CHECK (base_price_per_share > 0),
    frequency VARCHAR(20) NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('weekly', 'monthly', 'yearly')), -- 'weekly', 'monthly', 'yearly'
    due_day_of_period INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT true,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS down_payment_schemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    scheme_type VARCHAR(20) NOT NULL DEFAULT 'mandatory' CHECK (scheme_type IN ('mandatory', 'optional')), -- 'mandatory', 'optional'
    frequency VARCHAR(20) NOT NULL DEFAULT 'one_time' CHECK (frequency IN ('one_time', 'quarterly', 'yearly')), -- 'one_time', 'quarterly', 'yearly'
    due_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type VARCHAR(30) NOT NULL DEFAULT 'share_installment' CHECK (type IN ('share_installment', 'down_payment', 'ad_hoc')), -- 'share_installment', 'down_payment', 'ad_hoc'
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('bkash', 'nagad', 'rocket', 'bank_transfer', 'cash')), -- 'bkash', 'nagad', 'rocket', 'bank_transfer', 'cash'
    trx_id VARCHAR(100) NOT NULL,
    sender_account VARCHAR(100) NOT NULL,
    receipt_url TEXT,
    target_cycle VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')), -- 'PENDING', 'APPROVED', 'REJECTED'
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

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
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'MATURED', 'LIQUIDATED')), -- 'ACTIVE', 'MATURED', 'LIQUIDATED'
    investment_date DATE NOT NULL,
    maturity_date DATE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

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
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    ip_address VARCHAR(45),
    details_json JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    type VARCHAR(30) NOT NULL CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'other')), -- 'deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'other'
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    flow VARCHAR(10) NOT NULL CHECK (flow IN ('inflow', 'outflow')), -- 'inflow', 'outflow'
    reference_table VARCHAR(50),
    reference_id UUID,
    recorded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));

CREATE INDEX IF NOT EXISTS idx_organizations_slug_lower ON organizations(LOWER(slug));
CREATE INDEX IF NOT EXISTS idx_organizations_created_by ON organizations(created_by);

CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON organization_members(user_id);

CREATE INDEX IF NOT EXISTS idx_share_configs_org_active ON share_configurations(org_id, is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_down_payment_org_active ON down_payment_schemes(org_id, is_active);

CREATE INDEX IF NOT EXISTS idx_contributions_org_status ON contributions(org_id, status, paid_at);
CREATE INDEX IF NOT EXISTS idx_contributions_org_cycle ON contributions(org_id, target_cycle);
CREATE INDEX IF NOT EXISTS idx_contributions_org_user ON contributions(org_id, user_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS idx_contributions_org_user_cycle ON contributions(org_id, user_id, target_cycle);
CREATE INDEX IF NOT EXISTS idx_contributions_trx_id ON contributions(org_id, LOWER(trx_id));
CREATE INDEX IF NOT EXISTS idx_contributions_user_id ON contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_contributions_reviewed_by ON contributions(reviewed_by);

CREATE INDEX IF NOT EXISTS idx_investments_org_date ON investments(org_id, investment_date DESC);
CREATE INDEX IF NOT EXISTS idx_investments_org_status ON investments(org_id, status);
CREATE INDEX IF NOT EXISTS idx_investments_created_by ON investments(created_by);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_org_id ON notifications(org_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_org_created ON audit_logs(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_org_flow ON transactions(org_id, flow);
CREATE INDEX IF NOT EXISTS idx_transactions_recorded_by ON transactions(recorded_by);
