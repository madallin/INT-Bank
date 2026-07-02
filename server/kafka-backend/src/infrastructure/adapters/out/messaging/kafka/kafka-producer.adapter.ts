import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Kafka, Producer } from 'kafkajs';

import { EventPublisher } from '../../../../../core/ports/out/event-publisher.interface';
import { getKafkaClientConfig } from './kafka.config';

@Injectable()
export class KafkaProducerAdapter
  extends EventPublisher
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(KafkaProducerAdapter.name);
  private readonly kafka: Kafka;
  private producer: Producer;

  constructor()
  {
    super();

    this.kafka = new Kafka(getKafkaClientConfig('banking-nestjs-producer'));

    this.producer = this.kafka.producer({
      allowAutoTopicCreation: true,
      transactionTimeout: 30000,
      idempotent: true,
      maxInFlightRequests: 5,
    });
  }

  async onModuleInit(): Promise<void>
  {
    try
    {
      await this.producer.connect();
      this.logger.log('Kafka producer connected');
    }
    catch (error)
    {
      this.logger.error('Failed to connect Kafka producer', error);
    }
  }

  async onModuleDestroy(): Promise<void>
  {
    try
    {
      await this.producer.disconnect();
      this.logger.log('Kafka producer disconnected');
    }
    catch (error)
    {
      this.logger.warn('Error disconnecting Kafka producer', error);
    }
  }

  async publish<T extends Record<string, unknown>>(
    topic: string,
    key: string,
    event: T,
  ): Promise<void>
  {
    try
    {
      await this.producer.send({
        topic,
        messages: [
          {
            key,
            value: JSON.stringify(event),
            headers: {
              'content-type': 'application/json',
              'event-type': topic,
              'source': 'banking-nestjs',
              'timestamp': String(Date.now()),
            },
          },
        ],
        acks: -1, // Wait for all replicas — highest durability
      });

      this.logger.debug(
        `Published event to topic "${topic}": key=${key}`,
      );
    }
    catch (error)
    {
      this.logger.error(
        `Failed to publish event to topic "${topic}": key=${key}`,
        error,
      );
      throw error;
    }
  }
}
