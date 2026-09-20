-- ============================================================================
-- V7: Expand-Contract zero-downtime migration for accounts money storage.
--
-- Demonstrates the three-phase parallel-run pattern:
--   Phase 1 EXPAND   : add nullable balance_minor + dual-write trigger.
--   Phase 2 BACKFILL : batched copy of existing balances into balance_minor.
--   Phase 3 CONTRACT : enforce NOT NULL, index the new column, deprecate old.
--
-- The legacy account balance is stored in the "sold" column (see V1). The new
-- column stores the same amount in minor units (integer cents). While the
-- expand window is open the trigger keeps both representations consistent, so
-- old and new application versions can both read and write safely.
--
-- PostgreSQL 16 compatible. Uses idempotent DDL only; every statement is safe
-- to execute inside the Flyway-managed transaction.
-- ============================================================================

-- Bound how long DDL waits for locks and how long any single statement runs.
SET lock_timeout = '3s';
SET statement_timeout = '30s';

-- ----------------------------------------------------------------------------
-- PHASE 1 EXPAND
-- Add the new column as nullable with no default so PostgreSQL performs a
-- metadata-only change (no table rewrite, no long ACCESS EXCLUSIVE lock).
-- ----------------------------------------------------------------------------
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS balance_minor BIGINT;

-- Expand-state switch. The dual-write trigger only synchronises the two
-- representations while this flag is enabled; Phase 3 turns it off.
CREATE TABLE IF NOT EXISTS migration_flags (
    name TEXT PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

INSERT INTO migration_flags (name, enabled)
VALUES ('accounts_expand_balance_minor', TRUE)
ON CONFLICT (name) DO UPDATE SET enabled = EXCLUDED.enabled;

-- Dual-write trigger function: keeps accounts.sold (major units) and
-- accounts.balance_minor (minor units) consistent. It is a no-op once the
-- expand flag is disabled in Phase 3.
CREATE OR REPLACE FUNCTION sync_accounts_balance_minor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM migration_flags
        WHERE name = 'accounts_expand_balance_minor'
          AND enabled = TRUE
    ) THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.balance_minor IS NULL AND NEW.sold IS NOT NULL THEN
            NEW.balance_minor := round(NEW.sold * 100)::BIGINT;
        ELSIF NEW.sold IS NULL AND NEW.balance_minor IS NOT NULL THEN
            NEW.sold := round(NEW.balance_minor::NUMERIC / 100, 2);
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.sold IS DISTINCT FROM OLD.sold
       AND NEW.balance_minor IS NOT DISTINCT FROM OLD.balance_minor THEN
        NEW.balance_minor := round(NEW.sold * 100)::BIGINT;
    ELSIF NEW.balance_minor IS DISTINCT FROM OLD.balance_minor
          AND NEW.sold IS NOT DISTINCT FROM OLD.sold THEN
        NEW.sold := round(NEW.balance_minor::NUMERIC / 100, 2);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_accounts_balance_minor_sync ON accounts;
CREATE TRIGGER trg_accounts_balance_minor_sync
    BEFORE INSERT OR UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION sync_accounts_balance_minor();

-- ----------------------------------------------------------------------------
-- PHASE 2 BACKFILL
-- Copy existing balances in small batches so no single statement holds locks
-- for long. Each iteration touches at most batch_size rows.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE backfill_accounts_balance_minor(batch_size INTEGER DEFAULT 1000)
LANGUAGE plpgsql
AS $$
BEGIN
    LOOP
        UPDATE accounts
        SET balance_minor = round(sold * 100)::BIGINT
        WHERE id IN (
            SELECT id
            FROM accounts
            WHERE balance_minor IS NULL
            ORDER BY id
            LIMIT batch_size
        );

        EXIT WHEN NOT FOUND;
    END LOOP;
END;
$$;

CALL backfill_accounts_balance_minor(1000);

-- ----------------------------------------------------------------------------
-- PHASE 3 CONTRACT
-- Enforce the invariant with a NOT VALID constraint that is validated without
-- blocking reads or writes, index the new column, deprecate the legacy column,
-- and disable the dual-write trigger.
-- ----------------------------------------------------------------------------
ALTER TABLE accounts DROP CONSTRAINT IF EXISTS chk_accounts_balance_minor_not_null;
ALTER TABLE accounts
    ADD CONSTRAINT chk_accounts_balance_minor_not_null
    CHECK (balance_minor IS NOT NULL) NOT VALID;

ALTER TABLE accounts VALIDATE CONSTRAINT chk_accounts_balance_minor_not_null;

CREATE INDEX IF NOT EXISTS idx_accounts_balance_minor ON accounts (balance_minor);

COMMENT ON COLUMN accounts.sold IS
    'DEPRECATED: superseded by balance_minor (expand-contract Plan 2052)';

UPDATE migration_flags
SET enabled = FALSE
WHERE name = 'accounts_expand_balance_minor';
