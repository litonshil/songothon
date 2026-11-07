-- 000009_add_member_left_status.up.sql

-- A member who leaves an organization keeps their row (and every contribution,
-- audit entry and notification linked to them); only the status changes.
ALTER TABLE organization_members DROP CONSTRAINT IF EXISTS organization_members_status_check;
ALTER TABLE organization_members
    ADD CONSTRAINT organization_members_status_check
    CHECK (status IN ('active', 'invited', 'pending', 'suspended', 'removed', 'left'));

ALTER TABLE organization_members ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;
