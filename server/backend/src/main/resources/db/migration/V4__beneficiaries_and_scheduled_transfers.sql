-- V4: Saved Beneficiaries & Scheduled/Recurring Transfers

CREATE TABLE IF NOT EXISTS beneficiaries (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(120) NOT NULL,
    iban VARCHAR(34) NOT NULL,
    bank_name VARCHAR(64),
    nickname VARCHAR(64),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_beneficiaries_user_id ON beneficiaries (user_id);

CREATE TABLE IF NOT EXISTS scheduled_transfers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    from_account_id BIGINT NOT NULL,
    to_iban VARCHAR(34) NOT NULL,
    beneficiary_name VARCHAR(120) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'RON',
    reason VARCHAR(255) NOT NULL,
    frequency VARCHAR(20) NOT NULL DEFAULT 'MONTHLY', -- ONCE, WEEKLY, MONTHLY
    next_run_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, PAUSED, COMPLETED, CANCELLED
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scheduled_transfers_user ON scheduled_transfers (user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_transfers_next_run ON scheduled_transfers (next_run_date, status);
