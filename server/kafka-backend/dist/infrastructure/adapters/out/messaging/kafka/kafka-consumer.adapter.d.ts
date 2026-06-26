import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ProcessTransferUseCase } from '../../../../../application/use-cases/process-transfer.use-case';
export declare class KafkaConsumerAdapter implements OnModuleInit, OnModuleDestroy {
    private readonly processTransferUseCase;
    private readonly logger;
    private readonly kafka;
    private consumer;
    constructor(processTransferUseCase: ProcessTransferUseCase);
    onModuleInit(): Promise<void>;
    onModuleDestroy(): Promise<void>;
    private handleMessage;
    private publishToDlq;
    private commitOffset;
}
