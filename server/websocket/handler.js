'use strict';

const WebSocket = require('ws');
const { Client } = require('pg');

// Map: userId (string) -> ws
const clients = new Map();

/**
 * Attach WebSocket server and PostgreSQL LISTEN/NOTIFY to the HTTP(S) server.
 * @param {http.Server|https.Server} server
 */
function setupWebSocket(server) {
  const wss = new WebSocket.Server({ server });

  wss.on('connection', (ws, req) => {
    console.log('Client WebSocket conectat');

    ws.on('message', (message) => {
      console.log('WS message raw from client:', message);
      try {
        const data = JSON.parse(message);
        if (data.userId !== undefined && data.userId !== null) {
          const key = String(data.userId);
          clients.set(key, ws);
          ws._registeredUserId = key;
          console.log(`Client înregistrat pentru userId: ${key} (clients size: ${clients.size})`);
        } else {
          console.log('Mesaj WS primit fara userId:', data);
        }
      } catch (err) {
        console.error('Eroare la parsare mesaj WebSocket:', err, 'raw:', message);
      }
    });

    ws.on('close', (code, reason) => {
      if (ws._registeredUserId) {
        clients.delete(ws._registeredUserId);
        console.log(`Client pentru user ${ws._registeredUserId} s-a deconectat (clients size: ${clients.size})`);
      } else {
        console.log('Un client neînregistrat s-a deconectat');
      }
    });

    ws.on('error', (err) => {
      console.error('WebSocket client error:', err);
    });
  });

  // --- PostgreSQL LISTEN/NOTIFY ---
  const pgClient = new Client({
    host: process.env.PGHOST,
    port: process.env.PGPORT,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
  });

  pgClient.connect()
    .then(() => pgClient.query('LISTEN cont_aprobat'))
    .then(() => console.log('Ascult cont_aprobat PostgreSQL'))
    .catch(console.error);

  pgClient.on('notification', (msg) => {
    console.log('Notification received (raw payload):', msg.payload);

    let payload;
    try {
      payload = JSON.parse(msg.payload);
    } catch (e) {
      payload = msg.payload;
    }

    let userId = null;
    if (payload && typeof payload === 'object') {
      if (payload.id !== undefined) userId = payload.id;
      else if (payload.userId !== undefined) userId = payload.userId;
    } else {
      userId = payload;
    }

    if (userId === null || userId === undefined) {
      console.log('Nu am putut extrage userId din notificare. Payload:', payload);
      return;
    }

    const key = String(userId);
    const targetWs = clients.get(key);

    if (!targetWs) {
      console.log(`Niciun client WebSocket înregistrat pentru userId=${key}`);
      return;
    }

    const msgToClient = JSON.stringify({ type: 'contAprobat', id: Number(userId) });

    if (targetWs.readyState === WebSocket.OPEN) {
      try {
        targetWs.send(msgToClient);
        console.log(`Trimis notificare contAprobat la user ${key}: ${msgToClient}`);
      } catch (err) {
        console.error(`Eroare la trimiterea notificării către user ${key}:`, err);
      }
    } else {
      console.log(`WebSocket pentru user ${key} nu este OPEN (stare: ${targetWs.readyState}). Șterg din clients.`);
      clients.delete(key);
    }
  });

  return { wss, pgClient, clients };
}

module.exports = { setupWebSocket, clients };
