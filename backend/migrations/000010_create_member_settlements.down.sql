-- 000010_create_member_settlements.down.sql

DROP TABLE IF EXISTS member_settlements;

DELETE FROM transactions WHERE type = 'settlement';
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions
    ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'income', 'other'));
