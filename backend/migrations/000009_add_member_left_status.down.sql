-- 000009_add_member_left_status.down.sql

UPDATE organization_members SET status = 'removed' WHERE status = 'left';
ALTER TABLE organization_members DROP COLUMN IF EXISTS left_at;
ALTER TABLE organization_members DROP CONSTRAINT IF EXISTS organization_members_status_check;
ALTER TABLE organization_members
    ADD CONSTRAINT organization_members_status_check
    CHECK (status IN ('active', 'invited', 'pending', 'suspended', 'removed'));
