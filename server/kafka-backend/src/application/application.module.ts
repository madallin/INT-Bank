import { Module } from '@nestjs/common';

import { InitiateTransferUseCase } from './use-cases/initiate-transfer.use-case';
import { ProcessTransferUseCase } from './use-cases/process-transfer.use-case';
import { TransferUseCase } from '../core/ports/in/transfer.use-case';

@Module({
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
