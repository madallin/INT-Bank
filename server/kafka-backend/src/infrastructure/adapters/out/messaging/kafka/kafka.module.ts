import { Module, forwardRef } from '@nestjs/common';
import { KafkaProducerAdapter } from './kafka-producer.adapter';
import { KafkaConsumerAdapter } from './kafka-consumer.adapter';
import { EventPublisher } from '../../../../../core/ports/out/event-publisher.interface';
import { ApplicationModule } from '../../../../../application/application.module';

@Module({
  imports: [forwardRef(() => ApplicationModule)],
  providers: [
    {
      provide: EventPublisher,
      useClass: KafkaProducerAdapter,
    },
    KafkaProducerAdapter,
    KafkaConsumerAdapter,
  ],
  exports: [EventPublisher, KafkaProducerAdapter],
})
export class KafkaModule {}
