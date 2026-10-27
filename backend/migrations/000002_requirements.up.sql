-- Upgrade Migration: join approval workflow, invitations, password resets,
-- scheduled notifications, richer privacy controls and down-payment dates.

-- 1. Organization description and privacy toggles
ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '';
ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS allow_peer_list_visibility BOOLEAN NOT NULL DEFAULT true;

-- 2. Membership status now supports pending join requests and removed members
ALTER TABLE organization_members DROP CONSTRAINT IF EXISTS organization_members_status_check;
ALTER TABLE organization_members
    ADD CONSTRAINT organization_members_status_check
    CHECK (status IN ('active', 'invited', 'pending', 'suspended', 'removed'));

-- 3. Invitations for users who do not have an account yet
CREATE TABLE IF NOT EXISTS organization_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255),
    phone VARCHAR(50),
    role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (role IN ('org_admin', 'member')),
    shares_count INT NOT NULL DEFAULT 1 CHECK (shares_count >= 0),
    invited_by UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_invitation_contact CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_org_invitations_org_status ON organization_invitations(org_id, status);
CREATE INDEX IF NOT EXISTS idx_org_invitations_email ON organization_invitations(LOWER(email)) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_org_invitations_phone ON organization_invitations(phone) WHERE phone IS NOT NULL;

-- 4. Password reset tokens
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_password_reset_user ON password_reset_tokens(user_id);

-- 5. Scheduled and repeating admin notifications
CREATE TABLE IF NOT EXISTS scheduled_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    target_user_ids JSONB NOT NULL DEFAULT '[]',
    scheduled_at TIMESTAMPTZ NOT NULL,
    repeat_rule VARCHAR(20) NOT NULL DEFAULT 'once' CHECK (repeat_rule IN ('once', 'daily', 'weekly', 'monthly')),
    last_sent_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_due
    ON scheduled_notifications(scheduled_at) WHERE is_active = true;

-- 6. Down payment schemes gain an explicit start date
ALTER TABLE down_payment_schemes
    ADD COLUMN IF NOT EXISTS start_date DATE;

-- 7. Backfill start dates for existing schemes
UPDATE down_payment_schemes
SET start_date = COALESCE(start_date, due_date, created_at::date)
WHERE start_date IS NULL;
