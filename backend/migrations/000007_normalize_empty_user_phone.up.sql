-- 000007_normalize_empty_user_phone.up.sql

-- Phone is optional; store missing phones as NULL so the UNIQUE constraint
-- does not collide on empty strings.
UPDATE users SET phone = NULL WHERE TRIM(phone) = '';
