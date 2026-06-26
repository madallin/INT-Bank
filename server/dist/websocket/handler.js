"use strict";
// ============================================================
// WebSocket Handler — PostgreSQL LISTEN/NOTIFY bridge
// Attaches WS server + PG LISTEN to the HTTP(S) server.
// ============================================================
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.clients = void 0;
exports.setupWebSocket = setupWebSocket;
const ws_1 = __importStar(require("ws"));
const pg_1 = require("pg");
// Map: userId (string) -> ws
const clients = new Map();
exports.clients = clients;
/**
 * Attach WebSocket server and PostgreSQL LISTEN/NOTIFY to the HTTP(S) server.
 */
function setupWebSocket(server) {
    const wss = new ws_1.WebSocketServer({ server });
    wss.on('connection', (ws, req) => {
        const extWs = ws;
        console.log('Client WebSocket conectat');
        extWs.on('message', (message) => {
            console.log('WS message raw from client:', message);
            try {
                const data = JSON.parse(message.toString());
                if (data.userId !== undefined && data.userId !== null) {
                    const key = String(data.userId);
                    clients.set(key, extWs);
                    extWs._registeredUserId = key;
                    console.log(`Client înregistrat pentru userId: ${key} (clients size: ${clients.size})`);
                }
                else {
                    console.log('Mesaj WS primit fara userId:', data);
                }
            }
            catch (err) {
                console.error('Eroare la parsare mesaj WebSocket:', err, 'raw:', message);
            }
        });
        extWs.on('close', (code, reason) => {
            if (extWs._registeredUserId) {
                clients.delete(extWs._registeredUserId);
                console.log(`Client pentru user ${extWs._registeredUserId} s-a deconectat (clients size: ${clients.size})`);
            }
            else {
                console.log('Un client neînregistrat s-a deconectat');
            }
        });
        extWs.on('error', (err) => {
            console.error('WebSocket client error:', err);
        });
    });
    // --- PostgreSQL LISTEN/NOTIFY ---
    const pgClient = new pg_1.Client({
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
        let payload;
        try {
            payload = JSON.parse(msg.payload);
        }
        catch (e) {
            payload = msg.payload;
        }
        let userId = null;
        if (payload && typeof payload === 'object') {
            if (payload.id !== undefined)
                userId = String(payload.id);
            else if (payload.userId !== undefined)
                userId = String(payload.userId);
        }
        else {
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
        if (targetWs.readyState === ws_1.default.OPEN) {
            try {
                targetWs.send(msgToClient);
                console.log(`Trimis notificare contAprobat la user ${key}: ${msgToClient}`);
            }
            catch (err) {
                console.error(`Eroare la trimiterea notificării către user ${key}:`, err);
            }
        }
        else {
            console.log(`WebSocket pentru user ${key} nu este OPEN (stare: ${targetWs.readyState}). Șterg din clients.`);
            clients.delete(key);
        }
    });
    return { wss, pgClient, clients };
}
//# sourceMappingURL=handler.js.map