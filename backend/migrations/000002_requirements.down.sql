DROP TABLE IF EXISTS scheduled_notifications;
DROP TABLE IF EXISTS password_reset_tokens;
DROP TABLE IF EXISTS organization_invitations;

ALTER TABLE down_payment_schemes DROP COLUMN IF EXISTS start_date;

-- 'pending' and 'removed' do not exist in the original constraint, so those rows are mapped to 'suspended'.
UPDATE organization_members SET status = 'suspended' WHERE status IN ('pending', 'removed');
ALTER TABLE organization_members DROP CONSTRAINT IF EXISTS organization_members_status_check;
ALTER TABLE organization_members
    ADD CONSTRAINT organization_members_status_check
    CHECK (status IN ('active', 'invited', 'suspended'));

ALTER TABLE organizations DROP COLUMN IF EXISTS allow_peer_list_visibility;
ALTER TABLE organizations DROP COLUMN IF EXISTS description;
