-- INTBank schema baseline + banking-hardening tables.
-- Uses CREATE TABLE IF NOT EXISTS so it is safe to apply on databases that were
-- previously provisioned manually (ddl-auto: none). Flyway records this as V1.

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    nume VARCHAR(255) NOT NULL,
    prenume VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    nr_telefon VARCHAR(255) NOT NULL UNIQUE,
    sex VARCHAR(255) NOT NULL,
    data_nasterii DATE NOT NULL,
    cnp VARCHAR(255) NOT NULL UNIQUE,
    judet VARCHAR(255),
    localitate VARCHAR(255),
    adresa VARCHAR(255),
    cod_postal VARCHAR(255),
    place_id VARCHAR(255),
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    bloc VARCHAR(255),
    scara VARCHAR(255),
    apartament VARCHAR(255),
    cont_aprobat BOOLEAN DEFAULT FALSE,
    termeni_acceptati BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    "IBAN" VARCHAR(34) NOT NULL UNIQUE,
    moneda VARCHAR(3) NOT NULL,
    sold NUMERIC(15, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cards (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    account_id BIGINT NOT NULL REFERENCES accounts (id),
    numar_card VARCHAR(255) NOT NULL,
    cvv VARCHAR(255) NOT NULL,
    data_expirare VARCHAR(255) NOT NULL,
    detinator VARCHAR(255) NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transfers (
    id VARCHAR(64) PRIMARY KEY,
    from_account_id BIGINT REFERENCES accounts (id),
    to_account_id BIGINT REFERENCES accounts (id),
    amount NUMERIC(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    initiated_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    failure_reason VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS outbox (
    id BIGSERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    partition_key VARCHAR(255) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 5,
    last_error VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Idempotency audit records (HTTP Idempotency-Key + Kafka dedup backing)
CREATE TABLE IF NOT EXISTS idempotency_records (
    idempotency_key VARCHAR(64) PRIMARY KEY,
    user_id BIGINT,
    request_hash VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    response_payload TEXT,
    created_at TIMESTAMP,
    expires_at TIMESTAMP
);

-- Immutable double-entry ledger
CREATE TABLE IF NOT EXISTS journal_entries (
    id BIGSERIAL PRIMARY KEY,
    transfer_id VARCHAR(64) NOT NULL,
    account_id BIGINT NOT NULL,
    type VARCHAR(10) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'POSTED',
    created_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_journal_entries_transfer ON journal_entries (transfer_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_account ON journal_entries (account_id);

-- Durable saga state (replaces in-memory ConcurrentHashMap)
CREATE TABLE IF NOT EXISTS saga_instances (
    transfer_id VARCHAR(64) PRIMARY KEY,
    state VARCHAR(20) NOT NULL,
    current_step INTEGER,
    failure_reason TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS saga_steps (
    id BIGSERIAL PRIMARY KEY,
    saga_id VARCHAR(64) NOT NULL,
    step_name VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL,
    executed_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_saga_steps_saga ON saga_steps (saga_id);

-- Kafka consumer deduplication (at-least-once delivery safety)
CREATE TABLE IF NOT EXISTS processed_events (
    event_key VARCHAR(128) PRIMARY KEY,
    topic VARCHAR(64),
    "offset" BIGINT,
    processed_at TIMESTAMP
);
