import { Module } from '@nestjs/common';

import { DatabaseModule } from './adapters/out/persistence/typeorm/database.module';
import { KafkaModule } from './adapters/out/messaging/kafka/kafka.module';
import { TransferController } from './adapters/in/rest/transfer.controller';
import { ApplicationModule } from '../application/application.module';

@Module({
  imports: [
    DatabaseModule,
    KafkaModule,
    ApplicationModule,
  ],
  controllers: [
    TransferController,
  ],
  providers: [],
  exports: [],
})
export class InfrastructureModule {}
