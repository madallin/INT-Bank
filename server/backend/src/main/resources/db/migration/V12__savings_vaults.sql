-- ============================================================================
-- V12: Savings vaults.
--
-- A vault keeps its money in its own SAVINGS account, so every deposit and
-- withdrawal is an ordinary double-entry move between two of the customer's
-- accounts. Savings accounts are not listed with the current accounts and can
-- neither send nor receive transfers.
-- ============================================================================

SET lock_timeout = '3s';
SET statement_timeout = '30s';

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS type VARCHAR(16) NOT NULL DEFAULT 'CURRENT';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_accounts_type') THEN
        ALTER TABLE accounts ADD CONSTRAINT chk_accounts_type CHECK (type IN ('CURRENT', 'SAVINGS'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS vaults (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    account_id BIGINT NOT NULL UNIQUE REFERENCES accounts (id),
    name VARCHAR(60) NOT NULL,
    target_amount NUMERIC(15, 2) NOT NULL CHECK (target_amount > 0),
    target_date DATE,
    lock_type VARCHAR(16) NOT NULL DEFAULT 'FLEXIBLE' CHECK (lock_type IN ('FLEXIBLE', 'LOCKED')),
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP,
    -- A locked vault needs the date until which it stays locked.
    CONSTRAINT chk_vaults_locked_has_date CHECK (lock_type = 'FLEXIBLE' OR target_date IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_vaults_user ON vaults (user_id);
