import 'reflect-metadata';
import * as dotenv from 'dotenv';
dotenv.config();
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import { AppModule } from './app.module';
import { redis } from './config/redis';

const SHUTDOWN_TIMEOUT_MS = 15_000;
const DRAIN_CONNECTIONS_MS = 5_000;

async function bootstrap(): Promise<void>
{
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule, {
    logger: ['log','error','warn','debug','verbose'],
    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') ?? '*',
      methods: ['GET','POST','PUT','DELETE','OPTIONS'],
      credentials: true,
    },
  });
  app.useWebSocketAdapter(new WsAdapter(app));
  const port = process.env.PORT || 8080;
  await app.listen(port);
  const httpServer = app.getHttpServer();
  const activeConnections = new Set();
  httpServer.on('connection', (socket: any) => {
    activeConnections.add(socket);
    socket.on('close', () => activeConnections.delete(socket));
  });
  logger.log('App running on port ' + port);

  async function gracefulShutdown(signal: string)
  {
    logger.log('Shutting down due to ' + signal);
    httpServer.close(() => {});
    const drainTimer = setTimeout(() => {
      activeConnections.forEach((s: any) => s.destroy());
      activeConnections.clear();
    }, DRAIN_CONNECTIONS_MS);
    drainTimer.unref();
    try { await app.close(); logger.log('App closed'); }
    catch (e) { logger.error(e); }
    try { redis.disconnect(); logger.log('Redis disconnected'); }
    catch (e) { logger.warn(e); }
    clearTimeout(drainTimer);
    logger.log('Graceful shutdown complete');
  }

  function shutdownAndExit(signal: string)
  {
    const timer = setTimeout(() => process.exit(1), SHUTDOWN_TIMEOUT_MS);
    timer.unref();
    gracefulShutdown(signal).finally(() => { clearTimeout(timer); process.exit(0); });
  }

  process.on('SIGINT', () => shutdownAndExit('SIGINT'));
  process.on('SIGTERM', () => shutdownAndExit('SIGTERM'));
  process.on('uncaughtException', (e) => {
    logger.error(e);
    shutdownAndExit('uncaughtException');
  });
  process.on('unhandledRejection', (r) => {
    logger.error(r);
    shutdownAndExit('unhandledRejection');
  });
}
bootstrap().catch((e) => {
  const logger = new Logger('Bootstrap');
  logger.error(e);
  process.exit(1);
});
