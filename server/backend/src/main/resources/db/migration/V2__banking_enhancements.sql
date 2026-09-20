-- V2: Banking Enhancements: PIN authentication, lockout, transfer indexing, PCI-DSS card schema

ALTER TABLE users ADD COLUMN IF NOT EXISTS cod_pin VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_failed_attempts INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMP;

-- Indexing for high-frequency queries
CREATE INDEX IF NOT EXISTS idx_transfers_from_account ON transfers (from_account_id);
CREATE INDEX IF NOT EXISTS idx_transfers_to_account ON transfers (to_account_id);
CREATE INDEX IF NOT EXISTS idx_transfers_initiated_at ON transfers (initiated_at DESC);
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts (user_id);
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON cards (user_id);
CREATE INDEX IF NOT EXISTS idx_cards_account_id ON cards (account_id);

-- PCI-DSS: make cvv column nullable
ALTER TABLE cards ALTER COLUMN cvv DROP NOT NULL;
