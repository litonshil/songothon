ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS allow_member_collection_visibility BOOLEAN NOT NULL DEFAULT true;
