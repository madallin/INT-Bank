// ============================================================
// PostgreSQL Database Connection Pool
// ============================================================

import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.PGHOST,
  port: process.env.PGPORT ? Number(process.env.PGPORT) : 5432,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
  max: process.env.PGPOOL_MAX ? Number(process.env.PGPOOL_MAX) : 20,
  idleTimeoutMillis: process.env.PG_IDLE_MS ? Number(process.env.PG_IDLE_MS) : 30000,
  connectionTimeoutMillis: process.env.PG_CONN_TIMEOUT_MS ? Number(process.env.PG_CONN_TIMEOUT_MS) : 2000,
});

pool.on('error', (err: Error) => {
  console.error('Unexpected error on idle pg client', err);
});

export { pool };
