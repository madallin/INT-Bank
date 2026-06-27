import { Module, forwardRef } from '@nestjs/common';

import { InitiateTransferUseCase } from './use-cases/initiate-transfer.use-case';
import { ProcessTransferUseCase } from './use-cases/process-transfer.use-case';
import { TransferUseCase } from '../core/ports/in/transfer.use-case';
import { KafkaModule } from '../infrastructure/adapters/out/messaging/kafka/kafka.module';
import { DatabaseModule } from '../infrastructure/adapters/out/persistence/typeorm/database.module';


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
  ],
  exports: [
    TransferUseCase,
    ProcessTransferUseCase,
  ],
})
export class ApplicationModule {}
