import { Module, forwardRef } from '@nestjs/common';

import { InitiateTransferUseCase } from './use-cases/initiate-transfer.use-case';
import { ProcessTransferUseCase } from './use-cases/process-transfer.use-case';
import { TransferUseCase } from '../core/ports/in/transfer.use-case';
import { SagaOrchestrator } from './saga/saga-orchestrator';
import { KafkaModule } from '../infrastructure/adapters/out/messaging/kafka/kafka.module';
import { DatabaseModule } from '../infrastructure/adapters/out/persistence/typeorm/database.module';
import { RetryService } from '../infrastructure/services/retry.service';


@Module({
  imports: [
    forwardRef(() => KafkaModule),
    forwardRef(() => DatabaseModule),
  ],

  providers: [
    {
      provide: TransferUseCase,
      useClass: InitiateTransferUseCase,
    },
    ProcessTransferUseCase,
    SagaOrchestrator,
    RetryService,
  ],
  exports: [
    TransferUseCase,
    ProcessTransferUseCase,
    SagaOrchestrator,
  ],
})
export class ApplicationModule {}
