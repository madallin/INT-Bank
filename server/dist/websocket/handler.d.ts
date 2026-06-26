import WebSocket from 'ws';
import { Client } from 'pg';
import type { Server as HttpServer } from 'http';
import type { IncomingMessage } from 'http';
declare const clients: Map<string, WebSocket.WebSocket>;
/**
 * Attach WebSocket server and PostgreSQL LISTEN/NOTIFY to the HTTP(S) server.
 */
declare function setupWebSocket(server: HttpServer): {
    wss: WebSocket.Server<typeof WebSocket, typeof IncomingMessage>;
    pgClient: Client;
    clients: Map<string, WebSocket.WebSocket>;
};
export { setupWebSocket, clients };
//# sourceMappingURL=handler.d.ts.map