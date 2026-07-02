import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { KafkaProducerAdapter } from './kafka-producer.adapter';
import { KafkaConsumerAdapter } from './kafka-consumer.adapter';
import { DlqConsumerAdapter } from './dlq-consumer.adapter';
import { EventPublisher } from '../../../../../core/ports/out/event-publisher.interface';
import { ApplicationModule } from '../../../../../application/application.module';
import { OutboxOrmEntity } from '../../../out/persistence/typeorm/entities/outbox.orm-entity';

@Module({
  imports: [
    forwardRef(() => ApplicationModule),
    TypeOrmModule.forFeature([OutboxOrmEntity]),
  ],
  providers: [
    {
      provide: EventPublisher,
      useClass: KafkaProducerAdapter,
    },
    KafkaProducerAdapter,
    KafkaConsumerAdapter,
    DlqConsumerAdapter,
  ],
  exports: [
    EventPublisher,
    KafkaProducerAdapter,
    DlqConsumerAdapter,
    TypeOrmModule,
  ],
})
export class KafkaModule {}
