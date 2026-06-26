import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { EventPublisher } from '../../../../../core/ports/out/event-publisher.interface';
export declare class KafkaProducerAdapter extends EventPublisher implements OnModuleInit, OnModuleDestroy {
    private readonly logger;
    private readonly kafka;
    private producer;
    constructor();
    onModuleInit(): Promise<void>;
    onModuleDestroy(): Promise<void>;
    publish<T extends Record<string, unknown>>(topic: string, key: string, event: T): Promise<void>;
}
