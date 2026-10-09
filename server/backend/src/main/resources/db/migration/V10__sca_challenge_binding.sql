-- ============================================================================
-- V10: Bind step-up (SCA) challenges to the whole payment.
--
-- A challenge already carried amount + destination IBAN. It now also records
-- the source account and currency, so a confirmed challenge cannot be replayed
-- for the same amount from another account or in another currency.
-- Nullable: rows created before this migration simply expire (5-minute TTL).
-- ============================================================================

SET lock_timeout = '3s';
SET statement_timeout = '30s';

ALTER TABLE dynamic_challenges ADD COLUMN IF NOT EXISTS from_iban VARCHAR(34);
ALTER TABLE dynamic_challenges ADD COLUMN IF NOT EXISTS currency VARCHAR(3);
