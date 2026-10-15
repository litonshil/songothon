-- Down Migration: 000001_create_initial_schema.down.sql

DROP TRIGGER IF EXISTS trg_investments_updated_at ON investments;
DROP TRIGGER IF EXISTS trg_contributions_updated_at ON contributions;
DROP TRIGGER IF EXISTS trg_periods_updated_at ON contribution_periods;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
DROP FUNCTION IF EXISTS update_updated_at_column();

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS investments;
DROP TABLE IF EXISTS contributions;
DROP TABLE IF EXISTS contribution_periods;
DROP TABLE IF EXISTS users;
