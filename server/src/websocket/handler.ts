import { Server as HTTPServer } from 'http';
import WebSocket, { WebSocketServer } from 'ws';
import { Client as PGClient } from 'pg';

interface PendingNotification
{
  userId: number;
  type: string;
  payload: Record<string, unknown>;
  createdAt: Date;
}

interface UserConnection
{
  ws: WebSocket;
  userId: number;
}

const userConnections = new Map<number, Set<WebSocket>>();
const connections = new Set<UserConnection>();

const pgClient = new PGClient({
  connectionString: process.env.DATABASE_URL,
});

function broadcastNotification(userId: number, message: string): void
{
  const sockets = userConnections.get(userId);
  if(!sockets) return;

  for(const ws of sockets)
  {
    if(ws.readyState === WebSocket.OPEN)
    {
      ws.send(message);
    }
  }
}

export function setupWebSocket(server: HTTPServer): { pgClient: PGClient; broadcastToUser: (userId: number, message: string) => void }
{
  const wss = new WebSocketServer({ server, path: '/ws' });

  pgClient.connect();

  wss.on('connection', (ws: WebSocket, req) =>
  {
    const urlParams = new URLSearchParams(req.url?.split('?')[1] || '');
    const userId = parseInt(urlParams.get('userId') || '0', 10);

    if(!userId)
    {
      ws.close(4001, 'Missing userId');
      return;
    }

    const conn: UserConnection = { ws, userId };
    connections.add(conn);

    if(!userConnections.has(userId))
    {
      userConnections.set(userId, new Set());
    }
    userConnections.get(userId)!.add(ws);

    ws.on('close', () =>
    {
      connections.delete(conn);
      const sockets = userConnections.get(userId);
      if(sockets)
      {
        sockets.delete(ws);
        if(sockets.size === 0) userConnections.delete(userId);
      }
    });
  });

  return { pgClient, broadcastToUser: broadcastNotification };
}
