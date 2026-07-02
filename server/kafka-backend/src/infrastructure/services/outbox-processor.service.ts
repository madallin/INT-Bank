import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { OutboxOrmEntity, OutboxStatus } from '../adapters/out/persistence/typeorm/entities/outbox.orm-entity';
import { EventPublisher } from '../../core/ports/out/event-publisher.interface';

const POLL_INTERVAL_MS = 2000;
const BATCH_SIZE = 50;
const DEAD_LETTER_HOURS = 24;

@Injectable()
export class OutboxProcessorService implements OnModuleInit, OnModuleDestroy
{
    private readonly logger = new Logger(OutboxProcessorService.name);
    private pollTimer: NodeJS.Timeout | null = null;
    private isProcessing = false;

    constructor(
        @InjectRepository(OutboxOrmEntity)
        private readonly outboxRepo: Repository<OutboxOrmEntity>,
        private readonly eventPublisher: EventPublisher,
    ) {}

    onModuleInit(): void
    {
        this.startPolling();
    }

    onModuleDestroy(): void
    {
        this.stopPolling();
    }

    async processNow(): Promise<{ processed: number; failed: number }>
    {
        return this.processBatch();
    }

    private startPolling(): void
    {
        this.pollTimer = setInterval(async () =>
        {
            if(this.isProcessing)
            {
                return;
            }
            await this.processBatch();
        }, POLL_INTERVAL_MS);

        this.pollTimer.unref();
    }

    private stopPolling(): void
    {
        if(this.pollTimer)
        {
            clearInterval(this.pollTimer);
            this.pollTimer = null;
        }
    }

    private async processBatch(): Promise<{ processed: number; failed: number }>
    {
        this.isProcessing = true;
        let processed = 0;
        let failed = 0;

        try
        {
            // Expire stale entries before picking up new work
            await this.markDeadMessages();

            const pending = await this.outboxRepo.find({
                where: { status: OutboxStatus.PENDING },
                order: { createdAt: 'ASC' },
                take: BATCH_SIZE,
            });

            if(pending.length === 0)
            {
                return { processed: 0, failed: 0 };
            }

            for(const message of pending)
            {
                try
                {
                    await this.eventPublisher.publish(
                        message.topic,
                        message.partitionKey,
                        message.payload,
                    );

                    await this.outboxRepo.update(
                        { id: message.id },
                        { status: OutboxStatus.SENT },
                    );

                    processed++;
                }
                catch(err)
                {
                    const errMsg = err instanceof Error ? err.message : 'Unknown error';
                    const newRetryCount = message.retryCount + 1;
                    const isExhausted = newRetryCount >= message.maxRetries;

                    await this.outboxRepo.update(
                        { id: message.id },
                        {
                            status: isExhausted ? OutboxStatus.DEAD : OutboxStatus.PENDING,
                            retryCount: newRetryCount,
                            lastError: errMsg,
                        },
                    );

                    failed++;

                    this.logger.error(
                        `Outbox ${message.id} (${message.eventType}) ` +
                        `failed ${newRetryCount}/${message.maxRetries}: ${errMsg}`,
                    );
                }
            }
        }
        catch(err)
        {
            this.logger.error('Outbox processor batch failed', err);
        }
        finally
        {
            this.isProcessing = false;
        }

        return { processed, failed };
    }

    // Messages stuck in PENDING longer than 24h are unlikely to ever succeed
    private async markDeadMessages(): Promise<void>
    {
        const deadline = new Date(Date.now() - DEAD_LETTER_HOURS * 60 * 60 * 1000);

        const result = await this.outboxRepo.update(
            {
                status: OutboxStatus.PENDING,
                createdAt: LessThan(deadline),
            },
            {
                status: OutboxStatus.DEAD,
                lastError: `Expired after ${DEAD_LETTER_HOURS}h in outbox`,
            },
        );

        if(result.affected && result.affected > 0)
        {
            this.logger.warn(`Marked ${result.affected} stale outbox messages as DEAD`);
        }
    }

    async getStats(): Promise<{
        pending: number;
        sent: number;
        dead: number;
        total: number;
    }>
    {
        const [pending, sent, dead, total] = await Promise.all([
            this.outboxRepo.count({ where: { status: OutboxStatus.PENDING } }),
            this.outboxRepo.count({ where: { status: OutboxStatus.SENT } }),
            this.outboxRepo.count({ where: { status: OutboxStatus.DEAD } }),
            this.outboxRepo.count(),
        ]);

        return { pending, sent, dead, total };
    }

    async reprocessDead(): Promise<number>
    {
        const result = await this.outboxRepo.update(
            { status: OutboxStatus.DEAD },
            {
                status: OutboxStatus.PENDING,
                retryCount: 0,
                lastError: undefined,
            },
        );

        const count = result.affected ?? 0;
        this.logger.log(`Reprocessing ${count} dead outbox messages`);
        return count;
    }
}