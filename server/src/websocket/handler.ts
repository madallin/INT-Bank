// ============================================================
// WebSocket Handler — PostgreSQL LISTEN/NOTIFY bridge
// Attaches WS server + PG LISTEN to the HTTP(S) server.
// ============================================================

import WebSocket, { WebSocketServer } from 'ws';
import { Client } from 'pg';
import type { Server as HttpServer } from 'http';
import type { IncomingMessage } from 'http';

// Map: userId (string) -> ws
const clients = new Map<string, WebSocket.WebSocket>();

interface ExtendedWebSocket extends WebSocket.WebSocket {
  _registeredUserId?: string;
}

/**
 * Attach WebSocket server and PostgreSQL LISTEN/NOTIFY to the HTTP(S) server.
 */
function setupWebSocket(server: HttpServer) {
  const wss = new WebSocketServer({ server });

  wss.on('connection', (ws: WebSocket.WebSocket, req: IncomingMessage) => {
    const extWs = ws as ExtendedWebSocket;
    console.log('Client WebSocket conectat');

    extWs.on('message', (message: WebSocket.RawData) => {
      console.log('WS message raw from client:', message);
      try {
        const data = JSON.parse(message.toString());
        if (data.userId !== undefined && data.userId !== null) {
          const key = String(data.userId);
          clients.set(key, extWs);
          extWs._registeredUserId = key;
          console.log(`Client înregistrat pentru userId: ${key} (clients size: ${clients.size})`);
        } else {
          console.log('Mesaj WS primit fara userId:', data);
        }
      } catch (err) {
        console.error('Eroare la parsare mesaj WebSocket:', err, 'raw:', message);
      }
    });

    extWs.on('close', (code: number, reason: Buffer) => {
      if (extWs._registeredUserId) {
        clients.delete(extWs._registeredUserId);
        console.log(
          `Client pentru user ${extWs._registeredUserId} s-a deconectat (clients size: ${clients.size})`,
        );
      } else {
        console.log('Un client neînregistrat s-a deconectat');
      }
    });

    extWs.on('error', (err: Error) => {
      console.error('WebSocket client error:', err);
    });
  });

  // --- PostgreSQL LISTEN/NOTIFY ---
  const pgClient = new Client({
    host: process.env.PGHOST,
    port: process.env.PGPORT ? parseInt(process.env.PGPORT, 10) : undefined,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
  });

  pgClient
    .connect()
    .then(() => pgClient.query('LISTEN cont_aprobat'))
    .then(() => console.log('Ascult cont_aprobat PostgreSQL'))
    .catch(console.error);

  pgClient.on('notification', (msg) => {
    console.log('Notification received (raw payload):', msg.payload);

    let payload: any;
    try {
      payload = JSON.parse(msg.payload!);
    } catch (e) {
      payload = msg.payload;
    }

    let userId: string | null = null;
    if (payload && typeof payload === 'object') {
      if (payload.id !== undefined) userId = String(payload.id);
      else if (payload.userId !== undefined) userId = String(payload.userId);
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
      console.log(
        `WebSocket pentru user ${key} nu este OPEN (stare: ${targetWs.readyState}). Șterg din clients.`,
      );
      clients.delete(key);
    }
  });

  return { wss, pgClient, clients };
}

export { setupWebSocket, clients };
