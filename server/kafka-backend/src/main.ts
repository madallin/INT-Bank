// ============================================================
// NestJS Bootstrap — Hybrid Application
// Hexagonal Architecture — Entry Point
// Creates a hybrid NestJS application that supports both
// HTTP REST endpoints and a Kafka microservice listener.
// ============================================================

import 'reflect-metadata';
import * as dotenv from 'dotenv';
dotenv.config();
import { NestFactory } from '@nestjs/core';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';
import { Logger } from '@nestjs/common';

import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');

  // -------------------------------------------------------
  // 1. Create the main HTTP application
  // -------------------------------------------------------
  const app = await NestFactory.create(AppModule, {
    logger: ['log', 'error', 'warn', 'debug', 'verbose'],
    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') ?? '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      credentials: true,
    },
  });

  // -------------------------------------------------------
  // 2. Optionally connect Kafka as a NestJS microservice
  //    This enables @MessagePattern() decorator style if
  //    you prefer NestJS-native Kafka integration over raw KafkaJS.
  //    For this architecture, we use raw KafkaJS consumer in
  //    KafkaConsumerAdapter for more control (manual offset commit,
  //    DLQ handling, etc.).
  // -------------------------------------------------------
  // Uncomment below to enable NestJS microservice decorators:
  //
  // app.connectMicroservice<MicroserviceOptions>({
  //   transport: Transport.KAFKA,
  //   options: {
  //     client: {
  //       clientId: 'banking-nestjs',
  //       brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  //     },
  //     consumer: {
  //       groupId: 'banking-nestjs-group',
  //     },
  //     subscribe: {
  //       topics: ['transfer.initiated', 'transfer.completed', 'transfer.failed'],
  //     },
  //   },
  // });

  // -------------------------------------------------------
  // 3. Start the server
  // -------------------------------------------------------
  const port = process.env.PORT || 3001;
  await app.listen(port);

  logger.log(`🚀 NestJS Kafka Backend is running on port ${port}`);
  logger.log(`📡 HTTP: http://localhost:${port}`);
  logger.log(
    `📨 Kafka brokers: ${process.env.KAFKA_BROKERS || 'localhost:9092'}`,
  );
}

bootstrap().catch((error) => {
  const logger = new Logger('Bootstrap');
  logger.error('Failed to start application', error);
  process.exit(1);
});
