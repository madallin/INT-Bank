'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const http = require('http');
const { setupWebSocket } = require('./websocket/handler');
const { pool } = require('./config/database');
const { redis } = require('./config/redis');
const app = require('./app');

const PORT = process.env.PORT || 8080;

const server = http.createServer(app);

server.listen(PORT, () => {
  console.log(`Serverul a pornit cu succes pe portul ${PORT}`);
});

// --- WebSocket + PostgreSQL LISTEN/NOTIFY ---
const { pgClient } = setupWebSocket(server);

// --- Graceful shutdown ---
const shutdown = async () => {
  console.log('Închidere server...');
  try { await pool.end(); } catch (e) { console.error('Eroare la închiderea DB:', e); }
  try { await redis.quit(); } catch (e) { /* ignore */ }
  try { await pgClient.end(); } catch (e) { /* ignore */ }
  server.close(() => process.exit(0));
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);