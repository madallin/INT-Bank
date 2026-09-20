-- V3: Banking Compliance, Tamper-Evident Audit Trail & Dynamic Linking

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    action VARCHAR(64) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    previous_hash VARCHAR(64) NOT NULL,
    current_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS dynamic_challenges (
    challenge_id VARCHAR(64) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    to_iban VARCHAR(34) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    signature VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_dynamic_challenges_user ON dynamic_challenges (user_id);
