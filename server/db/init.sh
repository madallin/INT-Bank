#!/bin/bash
# server/db/init.sh
# Helper script to initialize the database
# Usage: ./db/init.sh

DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_USER="${PGUSER:-postgres}"
DB_NAME="${PGDATABASE:-intbank}"

echo "Initializing database $DB_NAME on $DB_HOST:$DB_PORT..."

PGPASSWORD="${PGPASSWORD}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
  SELECT 1 FROM pg_database WHERE datname = '$DB_NAME' | grep -q 1 || psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c 'CREATE DATABASE $DB_NAME;'
" 2>/dev/null

PGPASSWORD="${PGPASSWORD}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$(dirname "$0")/init.sql"

echo "Database initialization complete."
