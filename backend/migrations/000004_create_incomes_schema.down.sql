-- 000004_create_incomes_schema.down.sql

DELETE FROM transactions WHERE type = 'income' AND reference_table = 'incomes';

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions
    ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'investment_disbursement', 'investment_dividend', 'investment_liquidation', 'expense', 'other'));

DROP TABLE IF EXISTS incomes;
