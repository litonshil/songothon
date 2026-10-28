-- 000006_add_collection_visibility_to_organizations.down.sql

ALTER TABLE organizations DROP COLUMN IF EXISTS allow_member_collection_visibility;
