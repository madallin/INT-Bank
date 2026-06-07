-- =============================================
-- INT Bank - Database Initialization Script
-- Compatible with PostgreSQL (Supabase, Docker, etc.)
-- Run this entire script ONCE in SQL Editor
-- =============================================

-- Drop old tables from previous (incorrect) schema if they exist
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ==================== TABLES ====================

-- 1. utilizatori (users / customers)
CREATE TABLE IF NOT EXISTS utilizatori (
    id SERIAL PRIMARY KEY,
    nume VARCHAR(255) NOT NULL,
    prenume VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    nrtelefon VARCHAR(20) UNIQUE NOT NULL,
    sex VARCHAR(10),
    datanasterii DATE,
    cnp VARCHAR(20) UNIQUE NOT NULL,
    judet VARCHAR(100),
    localitate VARCHAR(100),
    adresa TEXT,
    cod_postal VARCHAR(10),
    place_id VARCHAR(255),
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    pincont VARCHAR(255),
    contaprobat BOOLEAN DEFAULT false,
    termeniacceptati BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. conturiBancare (bank accounts)
CREATE TABLE IF NOT EXISTS conturiBancare (
    id SERIAL PRIMARY KEY,
    userid INTEGER NOT NULL REFERENCES utilizatori(id) ON DELETE CASCADE,
    IBAN VARCHAR(34) UNIQUE NOT NULL,
    moneda VARCHAR(3) DEFAULT 'RON',
    sold NUMERIC(15,2) DEFAULT 0.00
);

-- 3. carduri (cards)
CREATE TABLE IF NOT EXISTS carduri (
    id SERIAL PRIMARY KEY,
    userid INTEGER NOT NULL REFERENCES utilizatori(id) ON DELETE CASCADE,
    numarCard TEXT NOT NULL,
    CVV TEXT NOT NULL,
    dataExpirare TEXT NOT NULL,
    detinator VARCHAR(255) NOT NULL,
    token VARCHAR(32) NOT NULL,
    accountid INTEGER REFERENCES conturiBancare(id) ON DELETE SET NULL
);

-- 4. localitati_referinta (reference table for city/county validation)
CREATE TABLE IF NOT EXISTS localitati_referinta (
    id SERIAL PRIMARY KEY,
    judet VARCHAR(100) NOT NULL,
    localitate VARCHAR(100) NOT NULL,
    cod_postal VARCHAR(10),
    UNIQUE(judet, localitate)
);

-- 5. transferuri (transfers / transactions)
CREATE TABLE IF NOT EXISTS transferuri (
    id SERIAL PRIMARY KEY,
    expeditor INTEGER NOT NULL REFERENCES conturiBancare(id),
    receptor INTEGER NOT NULL REFERENCES conturiBancare(id),
    suma NUMERIC(15,2) NOT NULL,
    moneda VARCHAR(3),
    motiv TEXT,
    dataTransfer TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== INDEXES ====================

CREATE INDEX IF NOT EXISTS idx_utilizatori_nrtelefon ON utilizatori(nrtelefon);
CREATE INDEX IF NOT EXISTS idx_utilizatori_cnp ON utilizatori(cnp);
CREATE INDEX IF NOT EXISTS idx_utilizatori_email ON utilizatori(email);
CREATE INDEX IF NOT EXISTS idx_utilizatori_place_id ON utilizatori(place_id);
CREATE INDEX IF NOT EXISTS idx_conturi_userid ON conturiBancare(userid);
CREATE INDEX IF NOT EXISTS idx_conturi_iban ON conturiBancare(IBAN);
CREATE INDEX IF NOT EXISTS idx_carduri_userid ON carduri(userid);
CREATE INDEX IF NOT EXISTS idx_carduri_accountid ON carduri(accountid);
CREATE INDEX IF NOT EXISTS idx_localitati_referinta ON localitati_referinta(judet, localitate);
CREATE INDEX IF NOT EXISTS idx_transferuri_expeditor ON transferuri(expeditor);
CREATE INDEX IF NOT EXISTS idx_transferuri_receptor ON transferuri(receptor);

-- ==================== TRIGGERS ====================

-- Auto-update updated_at on utilizatori
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trigger_update_utilizatori_updated_at ON utilizatori;
CREATE TRIGGER trigger_update_utilizatori_updated_at
    BEFORE UPDATE ON utilizatori
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- NOTIFY when contaprobat becomes true (for WebSocket real-time notifications)
CREATE OR REPLACE FUNCTION notify_cont_aprobat()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('cont_aprobat', json_build_object('id', NEW.id)::text);
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trigger_notify_cont_aprobat ON utilizatori;
CREATE TRIGGER trigger_notify_cont_aprobat
    AFTER UPDATE OF contaprobat ON utilizatori
    FOR EACH ROW
    WHEN (NEW.contaprobat = true)
    EXECUTE FUNCTION notify_cont_aprobat();
