"use strict";
// ============================================================
// Server Entry Point
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const http_1 = __importDefault(require("http"));
const handler_1 = require("./websocket/handler");
const database_1 = require("./config/database");
const redis_1 = require("./config/redis");
const app_1 = __importDefault(require("./app"));
const PORT = process.env.PORT || 8080;
const server = http_1.default.createServer(app_1.default);
server.listen(PORT, () => {
    console.log(`Serverul a pornit cu succes pe portul ${PORT}`);
});
// --- WebSocket + PostgreSQL LISTEN/NOTIFY ---
const { pgClient } = (0, handler_1.setupWebSocket)(server);
// --- Graceful shutdown ---
const shutdown = async () => {
    console.log('Închidere server...');
    try {
        await database_1.pool.end();
    }
    catch (e) {
        console.error('Eroare la închiderea DB:', e);
    }
    try {
        await redis_1.redis.quit();
    }
    catch (e) {
        /* ignore */
    }
    try {
        await pgClient.end();
    }
    catch (e) {
        /* ignore */
    }
    server.close(() => process.exit(0));
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
//# sourceMappingURL=index.js.map