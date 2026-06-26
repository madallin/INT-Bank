// ============================================================
// Kafka Consumer Adapter (Outbound Adapter — Driven Side)
// Hexagonal Architecture — Infrastructure Layer
//
// Listens to the `transfer.initiated` Kafka topic and delegates
// processing to the ProcessTransferUseCase.
//
// This adapter is responsible for:
//   - Subscribing to the topic
//   - Deserializing events
//   - Calling the use case
//   - Committing offsets after successful processing
//   - Dead-letter-queue (DLQ) handling for poison messages
// ============================================================

import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Kafka, Consumer, EachMessagePayload } from 'kafkajs';

import { ProcessTransferUseCase } from '../../../../../application/use-cases/process-transfer.use-case';
import { TransferInitiatedEvent } from '../../../../../core/domain/transfer.entity';
import { getKafkaClientConfig, getKafkaBrokers, getKafkaSslConfig, getKafkaSaslConfig } from './kafka.config';

@Injectable()
export class KafkaConsumerAdapter implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(KafkaConsumerAdapter.name);
  private readonly kafka: Kafka;
  private consumer: Consumer;

  constructor(
    private readonly processTransferUseCase: ProcessTransferUseCase,
  ) {
    this.kafka = new Kafka(getKafkaClientConfig('banking-nestjs-consumer'));

    this.consumer = this.kafka.consumer({
      groupId: process.env.KAFKA_CONSUMER_GROUP_ID || 'banking-transfer-group',
      sessionTimeout: 30000,
      heartbeatInterval: 3000,
      maxInFlightRequests: 1, // Process one message at a time for ordering
    });
  }

  async onModuleInit(): Promise<void> {
    try {
      await this.consumer.connect();
      this.logger.log('Kafka consumer connected');

      await this.consumer.subscribe({
        topic: 'transfer.initiated',
        fromBeginning: false,
      });

      await this.consumer.run({
        autoCommit: false, // Manual offset commit for at-least-once semantics
        eachMessage: async (payload: EachMessagePayload) => {
          await this.handleMessage(payload);
        },
      });

      this.logger.log(
        'Kafka consumer subscribed to "transfer.initiated" and running',
      );
    } catch (error) {
      this.logger.error('Failed to start Kafka consumer', error);
    }
  }

  async onModuleDestroy(): Promise<void> {
    try {
      await this.consumer.disconnect();
      this.logger.log('Kafka consumer disconnected');
    } catch (error) {
      this.logger.warn('Error disconnecting Kafka consumer', error);
    }
  }

  private async handleMessage(payload: EachMessagePayload): Promise<void> {
    const { topic, partition, message } = payload;
    const key = message.key?.toString() ?? 'unknown';
    const rawValue = message.value?.toString();

    if (!rawValue) {
      this.logger.warn(`Empty message received on "${topic}" [${partition}] key=${key}`);
      await this.commitOffset(payload);
      return;
    }

    this.logger.log(
      `Received message: topic="${topic}" [${partition}] offset=${message.offset} key=${key}`,
    );

    try {
      // Deserialize
      const event = JSON.parse(rawValue) as TransferInitiatedEvent;

      // Validate basic structure
      if (event.eventType !== 'transfer.initiated' || !event.transferId) {
        throw new Error(`Invalid event structure: ${rawValue.slice(0, 200)}`);
      }

      // Process
      await this.processTransferUseCase.execute(event);

      // Commit offset on success
      await this.commitOffset(payload);
      this.logger.log(
        `Successfully processed transfer [${event.transferId}] — offset committed`,
      );
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';

      this.logger.error(
        `Failed to process message: topic="${topic}" key=${key} offset=${message.offset} — ${errMsg}`,
      );

      // ---- Dead Letter Queue (DLQ) pattern ----
      // Publish failed message to a DLQ topic for later inspection/replay.
      try {
        const dlqTopic = 'transfer.initiated.dlq';
        await this.publishToDlq(dlqTopic, key, rawValue, errMsg);
        this.logger.warn(`Message sent to DLQ "${dlqTopic}": key=${key}`);
      } catch (dlqError) {
        this.logger.error(
          `Failed to send message to DLQ: key=${key}`,
          dlqError,
        );
      }

      // Commit offset to avoid re-processing poison messages indefinitely.
      // In production, you might want to pause the partition and alert instead.
      await this.commitOffset(payload);
    }
  }

  /**
   * Publish a failed message to the dead-letter queue.
   */
  private async publishToDlq(
    dlqTopic: string,
    key: string,
    originalValue: string,
    errorReason: string,
  ): Promise<void> {
    // Use the producer from KafkaProducerAdapter or a dedicated DLQ producer.
    // For simplicity, we create an ephemeral producer here.
    const { Kafka: KafkaDlq } = await import('kafkajs');
    const dlqKafka = new KafkaDlq({
      clientId: 'banking-dlq-producer',
      brokers: getKafkaBrokers(),
      ssl: getKafkaSslConfig(),
      ...(getKafkaSaslConfig() ? { sasl: getKafkaSaslConfig() } : {}),
    });
    const dlqProducer = dlqKafka.producer();

    try {
      await dlqProducer.connect();
      await dlqProducer.send({
        topic: dlqTopic,
        messages: [
          {
            key,
            value: originalValue,
            headers: {
              'dlq-reason': errorReason,
              'dlq-timestamp': String(Date.now()),
            },
          },
        ],
      });
    } finally {
      await dlqProducer.disconnect();
    }
  }

  /**
   * Manually commit the offset for the given message.
   */
  private async commitOffset(payload: EachMessagePayload): Promise<void> {
    const { topic, partition, message } = payload;
    await this.consumer.commitOffsets([
      {
        topic,
        partition,
        offset: String(Number(message.offset) + 1),
      },
    ]);
  }
}
