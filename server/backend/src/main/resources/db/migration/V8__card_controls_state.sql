-- ============================================================================
-- V8: Persist card controls (freeze, spending limit, payment channels).
--
-- Until now freeze/unfreeze/limits only wrote an audit row and the card list
-- always reported "active". These columns make the customer's choice durable.
--
-- Constant defaults on PostgreSQL 11+ are metadata-only (no table rewrite), so
-- this is safe under load like V7.
-- ============================================================================

SET lock_timeout = '3s';
SET statement_timeout = '30s';

ALTER TABLE cards ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE cards ADD COLUMN IF NOT EXISTS spending_limit NUMERIC(15, 2) NOT NULL DEFAULT 5000.00;
ALTER TABLE cards ADD COLUMN IF NOT EXISTS online_payments_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE cards ADD COLUMN IF NOT EXISTS contactless_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE cards ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMP;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cards_status') THEN
        ALTER TABLE cards ADD CONSTRAINT chk_cards_status CHECK (status IN ('ACTIVE', 'FROZEN'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cards_spending_limit') THEN
        ALTER TABLE cards ADD CONSTRAINT chk_cards_spending_limit CHECK (spending_limit > 0);
    END IF;
END $$;
