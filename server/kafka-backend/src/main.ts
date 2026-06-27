import 'reflect-metadata';
import * as dotenv from 'dotenv';
dotenv.config();
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';

import { AppModule } from './app.module';

async function bootstrap(): Promise<void>
{
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create(AppModule, {
    logger: ['log', 'error', 'warn', 'debug', 'verbose'],
    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') ?? '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      credentials: true,
    },
  });

  // Use raw WebSocket (ws) adapter instead of Socket.IO
  app.useWebSocketAdapter(new WsAdapter(app));

  const port = process.env.PORT || 8080;
  await app.listen(port);

  logger.log(`NestJS Kafka Backend is running on port ${port}`);
  logger.log(`HTTP: http://localhost:${port}`);
  logger.log(
    `Kafka brokers: ${process.env.KAFKA_BROKERS || 'localhost:9092'}`,
  );

  // Graceful shutdown
  const shutdown = async () =>
  {
    logger.log('Shutting down gracefully...');
    await app.close();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

bootstrap().catch((error) =>
{
  const logger = new Logger('Bootstrap');
  logger.error('Failed to start application', error);
  process.exit(1);
});

