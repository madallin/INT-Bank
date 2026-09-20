-- V6: Optimistic locking for accounts to guarantee ACID concurrent updates
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_accounts_version ON accounts(id, version);
