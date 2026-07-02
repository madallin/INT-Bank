import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Kafka, Consumer, EachMessagePayload } from 'kafkajs';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { ProcessTransferUseCase } from '../../../../../application/use-cases/process-transfer.use-case';
import { TransferInitiatedEvent } from '../../../../../core/domain/transfer.entity';
import { getKafkaClientConfig, getKafkaBrokers, getKafkaSslConfig, getKafkaSaslConfig } from './kafka.config';
import { RetryService, BackoffStrategy } from '../../../../services/retry.service';
import { OutboxOrmEntity, OutboxStatus } from '../../../out/persistence/typeorm/entities/outbox.orm-entity';

const DLQ_TOPIC = 'transfer.initiated.dlq';
const MAX_DLQ_RETRIES = 3;
const RETRY_DELAYS_MS = [120000, 300000, 900000]; // 2min, 5min, 15min
const TOPIC_RETRY_INTERVAL_MS = 30000; // Retry subscription every 30s if topic doesn't exist yet

interface DlqMessageMetadata
{
  retryCount: number;
  firstFailureAt: string;
  lastFailureAt: string;
  lastError: string;
  originalKey: string;
}

@Injectable()
export class DlqConsumerAdapter implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(DlqConsumerAdapter.name);
  private readonly kafka: Kafka;
  private consumer: Consumer;
  private isRunning = false;
  private subscriptionTimer: NodeJS.Timeout | null = null;

  constructor(
    private readonly processTransferUseCase: ProcessTransferUseCase,
    private readonly retryService: RetryService,
    @InjectRepository(OutboxOrmEntity)
    private readonly outboxRepo: Repository<OutboxOrmEntity>,
  )
  {
    this.kafka = new Kafka(getKafkaClientConfig('banking-dlq-consumer'));

    this.consumer = this.kafka.consumer({
      groupId: 'banking-transfer-dlq-group',
      sessionTimeout: 30000,
      heartbeatInterval: 3000,
      maxInFlightRequests: 1,
    });
  }

  async onModuleInit(): Promise<void>
  {
    await new Promise(resolve => setTimeout(resolve, 5000));
    await this.connectAndSubscribe();
  }

  async onModuleDestroy(): Promise<void>
  {
    this.isRunning = false;

    if(this.subscriptionTimer)
    {
      clearInterval(this.subscriptionTimer);
      this.subscriptionTimer = null;
    }

    try
    {
      await this.consumer.disconnect();
      this.logger.log('DLQ Consumer disconnected');
    }
    catch(error)
    {
      this.logger.warn('Error disconnecting DLQ Consumer', error);
    }
  }

  async getStats(): Promise<{
    deadMessages: number;
    pendingRetries: number;
    permanentlyFailed: number;
  }>
  {
    const [deadInOutbox, pendingRetries] = await Promise.all([
      this.outboxRepo.count({
        where: { status: OutboxStatus.DEAD, topic: DLQ_TOPIC },
      }),
      this.outboxRepo.count({
        where: { status: OutboxStatus.PENDING, topic: DLQ_TOPIC },
      }),
    ]);

    return {
      deadMessages: deadInOutbox,
      pendingRetries,
      permanentlyFailed: deadInOutbox,
    };
  }

  // Topic may not exist yet — retry subscription periodically until it's created
  // by the main consumer's publishToDlq() (which has allowAutoTopicCreation: true)
  private async connectAndSubscribe(): Promise<void>
  {
    try
    {
      await this.consumer.connect();
      this.logger.log('DLQ Consumer connected');

      await this.subscribe();
    }
    catch(error)
    {
      this.logger.warn(
        `DLQ consumer failed to connect: ${error instanceof Error ? error.message : 'Unknown error'}. ` +
        `Retrying in ${TOPIC_RETRY_INTERVAL_MS / 1000}s...`,
      );

      this.scheduleSubscriptionRetry();
    }
  }

  private scheduleSubscriptionRetry(): void
  {
    if(this.subscriptionTimer)
    {
      return;
    }

    this.subscriptionTimer = setInterval(async () =>
    {
      if(this.isRunning)
      {
        clearInterval(this.subscriptionTimer!);
        this.subscriptionTimer = null;
        return;
      }

      try
      {
        await this.subscribe();

        if(this.subscriptionTimer)
        {
          clearInterval(this.subscriptionTimer);
          this.subscriptionTimer = null;
        }
      }
      catch(error)
      {
        this.logger.warn(
          `DLQ subscription retry failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        );
      }
    }, TOPIC_RETRY_INTERVAL_MS);

    this.subscriptionTimer.unref();
  }

  private async subscribe(): Promise<void>
  {
    await this.consumer.subscribe({
      topic: DLQ_TOPIC,
      fromBeginning: false,
    });

    await this.consumer.run({
      autoCommit: false,
      eachMessage: async (payload: EachMessagePayload) =>
      {
        await this.handleDlqMessage(payload);
      },
    });

    this.isRunning = true;
    this.logger.log(`DLQ Consumer subscribed to "${DLQ_TOPIC}" and running`);
  }

  private async handleDlqMessage(payload: EachMessagePayload): Promise<void>
  {
    const { topic, partition, message } = payload;
    const key = message.key?.toString() ?? 'unknown';
    const rawValue = message.value?.toString();

    if(!rawValue)
    {
      this.logger.warn(`Empty DLQ message on "${topic}" key=${key}`);
      await this.commitOffset(payload);
      return;
    }

    const metadata = this.parseMetadata(message.headers, key);
    const retryCount = metadata.retryCount;

    this.logger.log(
      `DLQ message received: topic="${topic}" key=${key} ` +
      `retry=${retryCount}/${MAX_DLQ_RETRIES}`,
    );

    if(retryCount >= MAX_DLQ_RETRIES)
    {
      await this.archivePermanently(key, rawValue, metadata);
      await this.commitOffset(payload);
      return;
    }

    const delayMs = RETRY_DELAYS_MS[retryCount] ?? RETRY_DELAYS_MS[RETRY_DELAYS_MS.length - 1];

    this.logger.log(
      `DLQ retry ${retryCount + 1}/${MAX_DLQ_RETRIES} for key=${key} in ${delayMs}ms`,
    );

    await this.sleep(delayMs);

    try
    {
      const event = JSON.parse(rawValue) as TransferInitiatedEvent;

      if(event.eventType !== 'transfer.initiated' || !event.transferId)
      {
        throw new Error(`Invalid event structure in DLQ message`);
      }

      await this.retryService.execute(
        () => this.processTransferUseCase.execute(event),
        {
          maxAttempts: 1,
          strategy: BackoffStrategy.EXPONENTIAL,
        },
      );

      this.logger.log(`DLQ message for transfer [${event.transferId}] successfully reprocessed`);
      await this.commitOffset(payload);
    }
    catch(error)
    {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';

      this.logger.error(
        `DLQ retry ${retryCount + 1} failed for key=${key}: ${errMsg}`,
      );

      await this.republishToDlq(key, rawValue, {
        ...metadata,
        retryCount: retryCount + 1,
        lastFailureAt: new Date().toISOString(),
        lastError: errMsg,
      });

      await this.commitOffset(payload);
    }
  }

  private parseMetadata(
    headers: unknown,
    key: string,
  ): DlqMessageMetadata
  {
    const getHeader = (name: string): string =>
    {
      const rawHeaders = headers as Record<string, unknown> | undefined;
      const val = rawHeaders?.[name];
      if(typeof val === 'string') return val;
      if(Buffer.isBuffer(val)) return val.toString();
      return '';
    };

    return {
      retryCount: parseInt(getHeader('dlq-retry-count') || '0', 10),
      firstFailureAt: getHeader('dlq-first-failure') || new Date().toISOString(),
      lastFailureAt: getHeader('dlq-timestamp') || new Date().toISOString(),
      lastError: getHeader('dlq-reason') || 'Unknown',
      originalKey: key,
    };
  }

  private async republishToDlq(
    key: string,
    value: string,
    metadata: DlqMessageMetadata,
  ): Promise<void>
  {
    const { Kafka: KafkaDlq } = await import('kafkajs');
    const dlqKafka = new KafkaDlq({
      clientId: 'banking-dlq-republisher',
      brokers: getKafkaBrokers(),
      ssl: getKafkaSslConfig(),
      ...(getKafkaSaslConfig() ? { sasl: getKafkaSaslConfig() } : {}),
    });
    const dlqProducer = dlqKafka.producer({ idempotent: true });

    try
    {
      await dlqProducer.connect();
      await dlqProducer.send({
        topic: DLQ_TOPIC,
        messages: [
          {
            key,
            value,
            headers: {
              'dlq-retry-count': String(metadata.retryCount),
              'dlq-first-failure': metadata.firstFailureAt,
              'dlq-timestamp': String(Date.now()),
              'dlq-reason': metadata.lastError,
              'dlq-original-key': metadata.originalKey,
            },
          },
        ],
      });
    }
    finally
    {
      await dlqProducer.disconnect();
    }
  }

  private async archivePermanently(
    key: string,
    rawValue: string,
    metadata: DlqMessageMetadata,
  ): Promise<void>
  {
    this.logger.error(
      `DLQ message permanently failed after ${MAX_DLQ_RETRIES} retries: key=${key}`,
    );

    try
    {
      const outboxEntry = this.outboxRepo.create({
        aggregateId: key,
        eventType: 'transfer.initiated',
        topic: DLQ_TOPIC,
        partitionKey: key,
        payload: JSON.parse(rawValue),
        status: OutboxStatus.DEAD,
        retryCount: metadata.retryCount,
        maxRetries: MAX_DLQ_RETRIES,
        lastError: `DLQ exhausted after ${MAX_DLQ_RETRIES} retries. Last error: ${metadata.lastError}`,
      });
      await this.outboxRepo.save(outboxEntry);
    }
    catch(err)
    {
      this.logger.error(`Failed to archive DLQ message: key=${key}`, err);
    }
  }

  private async commitOffset(payload: EachMessagePayload): Promise<void>
  {
    const { topic, partition, message } = payload;
    await this.consumer.commitOffsets([
      {
        topic,
        partition,
        offset: String(Number(message.offset) + 1),
      },
    ]);
  }

  private sleep(ms: number): Promise<void>
  {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}