-- 000007_normalize_empty_user_phone.down.sql

-- No-op: NULL phones are valid and cannot be safely converted back.
SELECT 1;
