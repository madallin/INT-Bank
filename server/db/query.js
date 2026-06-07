// server/db/query.js
// Minimal helper to reduce raw query boilerplate

const { pool } = require('../config/database');

/**
 * Execute a single query and return rows.
 * Handles connection acquire/release automatically.
 */
async function query(text, params = []) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result.rows;
  } finally {
    client.release();
  }
}

/**
 * Execute a single query and return the first row (or null).
 */
async function queryOne(text, params = []) {
  const rows = await query(text, params);
  return rows.length > 0 ? rows[0] : null;
}

/**
 * Execute a query and return the row count.
 */
async function execute(text, params = []) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result.rowCount;
  } finally {
    client.release();
  }
}

/**
 * Run a callback inside a transaction with automatic BEGIN/COMMIT/ROLLBACK.
 * 
 * Example:
 *   await transaction(async (client) => {
 *     const rows = await client.query('SELECT ... FOR UPDATE', [id]);
 *     await client.query('UPDATE ... SET ...', [val, id]);
 *   });
 */
async function transaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { query, queryOne, execute, transaction };
