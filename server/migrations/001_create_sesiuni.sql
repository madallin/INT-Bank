-- migration: 001_create_sesiuni.sql
-- Creează tabela pentru sesiuni JWT (refresh token rotation)

CREATE TABLE IF NOT EXISTS sesiuni (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES utilizatori(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Index pentru căutare rapidă după user_id
CREATE INDEX IF NOT EXISTS idx_sesiuni_user_id ON sesiuni(user_id);

-- Index pentru ștergerea sesiunilor expirate
CREATE INDEX IF NOT EXISTS idx_sesiuni_expires_at ON sesiuni(expires_at);
