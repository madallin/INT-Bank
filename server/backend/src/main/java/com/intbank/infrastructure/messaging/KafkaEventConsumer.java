package com.intbank.infrastructure.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class KafkaEventConsumer
{

    private static final Logger log = LoggerFactory.getLogger(KafkaEventConsumer.class);

    private final ProcessTransferUseCase processTransferUseCase;
    private final ObjectMapper objectMapper;
    private final com.intbank.infrastructure.persistence.repository.ProcessedEventJpaRepository processedEventRepo;

    public KafkaEventConsumer(ProcessTransferUseCase processTransferUseCase,
                              ObjectMapper objectMapper,
                              com.intbank.infrastructure.persistence.repository.ProcessedEventJpaRepository processedEventRepo)
    {
        this.processTransferUseCase = processTransferUseCase;
        this.objectMapper = objectMapper;
        this.processedEventRepo = processedEventRepo;
    }

    @KafkaListener(
        topics = "transfer.initiated",
        groupId = "${spring.kafka.consumer.group-id}",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void onTransferInitiated(ConsumerRecord<String, Object> record, Acknowledgment ack)
    {
        String eventKey = record.topic() + ":" + record.partition() + ":" + record.offset();
        try {
            log.info("Received transfer.initiated event [key={}, offset={}]", record.key(), record.offset());

            if (processedEventRepo.existsById(eventKey))
            {
                log.info("Duplicate Kafka event detected [key={}], skipping and acknowledging", eventKey);
                ack.acknowledge();
                return;
            }

            TransferInitiatedEvent event = objectMapper.convertValue(toMap(record.value()), TransferInitiatedEvent.class);
            processTransferUseCase.execute(event);

            var processed = new com.intbank.infrastructure.persistence.entity.ProcessedEventJpaEntity();
            processed.setEventKey(eventKey);
            processed.setTopic(record.topic());
            processed.setKafkaOffset(record.offset());
            processed.setProcessedAt(java.time.Instant.now());
            processedEventRepo.save(processed);

            ack.acknowledge();
        } catch (Exception e) {
            log.error("Error processing transfer.initiated event: {}", e.getMessage(), e);
            // Don't acknowledge - message will be retried and routed to DLT
            throw new RuntimeException("Failed to process transfer event", e);
        }
    }

    @KafkaListener(
        topics = "transfer.initiated.DLT",
        groupId = "${spring.kafka.consumer.group-id}-dlt"
    )
    public void onTransferInitiatedDlt(ConsumerRecord<String, Object> record, Acknowledgment ack)
    {
        log.error("ALERT_SRE_DLT: Received dead-letter event on {}. Offset: {}, Key: {}, Payload: {}",
                record.topic(), record.offset(), record.key(), record.value());
        ack.acknowledge();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> toMap(Object value) throws Exception
    {
        if (value instanceof Map<?, ?> map)
        {
            return (Map<String, Object>) map;
        }
        if (value instanceof String str)
        {
            return objectMapper.readValue(str, Map.class);
        }
        return objectMapper.convertValue(value, Map.class);
    }
}
