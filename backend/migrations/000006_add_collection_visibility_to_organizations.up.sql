-- 000006_add_collection_visibility_to_organizations.up.sql

ALTER TABLE organizations ADD COLUMN IF NOT EXISTS allow_member_collection_visibility BOOLEAN NOT NULL DEFAULT true;
