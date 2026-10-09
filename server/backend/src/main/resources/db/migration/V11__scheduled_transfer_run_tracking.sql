-- ============================================================================
-- V11: Track the outcome of scheduled-transfer runs.
--
-- A run that cannot be initiated (limit reached, destination closed, ...) is
-- recorded and the customer is notified. One-off payments become FAILED;
-- recurring ones move to the next date and pause after 3 failures in a row.
-- ============================================================================

SET lock_timeout = '3s';
SET statement_timeout = '30s';

ALTER TABLE scheduled_transfers ADD COLUMN IF NOT EXISTS last_run_at TIMESTAMP;
ALTER TABLE scheduled_transfers ADD COLUMN IF NOT EXISTS last_error VARCHAR(255);
ALTER TABLE scheduled_transfers ADD COLUMN IF NOT EXISTS consecutive_failures INTEGER NOT NULL DEFAULT 0;
