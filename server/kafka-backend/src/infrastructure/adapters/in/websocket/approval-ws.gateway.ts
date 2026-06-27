import
{
    WebSocketGateway,
    WebSocketServer,
    OnGatewayConnection,
    OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { WebSocket, WebSocketServer as WsServer } from 'ws';
import { IncomingMessage } from 'http';

interface UserConnection
{
    ws: WebSocket;
    userId: number;
}

@WebSocketGateway(
{
    path: '/ws',
    cors: { origin: '*', credentials: true },
})
export class ApprovalWsGateway implements OnGatewayConnection, OnGatewayDisconnect
{
    private readonly logger = new Logger(ApprovalWsGateway.name);

    @WebSocketServer()
    server!: WsServer;

    private readonly userConnections = new Map<number, Set<WebSocket>>();
    private readonly connections = new Set<UserConnection>();

    handleConnection(client: WebSocket, req: IncomingMessage): void
    {
        const urlParams = new URLSearchParams(req.url?.split('?')[1] || '');
        const userId = parseInt(urlParams.get('userId') || '0', 10);

        if(!userId)
        {
            client.close(4001, 'Missing userId');
            return;
        }

        const conn: UserConnection = { ws: client, userId };
        this.connections.add(conn);

        if(!this.userConnections.has(userId))
        {
            this.userConnections.set(userId, new Set());
        }
        this.userConnections.get(userId)!.add(client);

        this.logger.debug(`WebSocket connected: userId=${userId}`);
    }

    handleDisconnect(client: WebSocket): void
    {
        for(const conn of this.connections)
        {
            if(conn.ws === client)
            {
                this.connections.delete(conn);
                const sockets = this.userConnections.get(conn.userId);
                if(sockets)
                {
                    sockets.delete(client);
                    if(sockets.size === 0)
                    {
                        this.userConnections.delete(conn.userId);
                    }
                }
                this.logger.debug(`WebSocket disconnected: userId=${conn.userId}`);
                break;
            }
        }
    }

    broadcastToUser(userId: number, message: string): void
    {
        const sockets = this.userConnections.get(userId);
        if(!sockets) return;

        for(const ws of sockets)
        {
            if(ws.readyState === WebSocket.OPEN)
            {
                ws.send(message);
            }
        }
    }
}
