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

    public KafkaEventConsumer(ProcessTransferUseCase processTransferUseCase, ObjectMapper objectMapper)
    {
        this.processTransferUseCase = processTransferUseCase;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(
        topics = "transfer.initiated",
        groupId = "${spring.kafka.consumer.group-id}",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void onTransferInitiated(ConsumerRecord<String, Object> record, Acknowledgment ack)
    {
        try {
            log.info("Received transfer.initiated event [key={}, offset={}]", record.key(), record.offset());

            TransferInitiatedEvent event = objectMapper.convertValue(toMap(record.value()), TransferInitiatedEvent.class);
            processTransferUseCase.execute(event);
            ack.acknowledge();
        } catch (Exception e) {
            log.error("Error processing transfer.initiated event: {}", e.getMessage(), e);
            // Don't acknowledge - message will be retried
            throw new RuntimeException("Failed to process transfer event", e);
        }
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
