-- 000003_create_expenses_schema.down.sql

DELETE FROM transactions WHERE type = 'expense' AND reference_table = 'expenses';

DROP TABLE IF EXISTS expenses;
