"use strict";
// ============================================================
// PostgreSQL Database Connection Pool
// ============================================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.pool = void 0;
const pg_1 = require("pg");
const pool = new pg_1.Pool({
    host: process.env.PGHOST,
    port: process.env.PGPORT ? Number(process.env.PGPORT) : 5432,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
    max: process.env.PGPOOL_MAX ? Number(process.env.PGPOOL_MAX) : 20,
    idleTimeoutMillis: process.env.PG_IDLE_MS ? Number(process.env.PG_IDLE_MS) : 30000,
    connectionTimeoutMillis: process.env.PG_CONN_TIMEOUT_MS ? Number(process.env.PG_CONN_TIMEOUT_MS) : 2000,
});
exports.pool = pool;
pool.on('error', (err) => {
    console.error('Unexpected error on idle pg client', err);
});
//# sourceMappingURL=database.js.map