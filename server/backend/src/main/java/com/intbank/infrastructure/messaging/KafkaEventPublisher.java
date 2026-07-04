package com.intbank.infrastructure.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.core.port.out.EventPublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Component
public class KafkaEventPublisher implements EventPublisher
{

    private static final Logger log = LoggerFactory.getLogger(KafkaEventPublisher.class);

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final ObjectMapper objectMapper;

    public KafkaEventPublisher(KafkaTemplate<String, Object> kafkaTemplate, ObjectMapper objectMapper)
    {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public void publish(String topic, String key, Map<String, Object> event)
    {
        try {
            String payload = objectMapper.writeValueAsString(event);
            CompletableFuture<SendResult<String, Object>> future = kafkaTemplate.send(topic, key, event);
            future.whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to publish event to topic {} [key={}]: {}", topic, key, ex.getMessage(), ex);
                } else {
                    log.debug("Published event to topic {} partition {} offset {}",
                            topic, result.getRecordMetadata().partition(), result.getRecordMetadata().offset());
                }
            });
        } catch (Exception e) {
            log.error("Error serializing event for topic {}: {}", topic, e.getMessage(), e);
            throw new RuntimeException("Failed to publish event", e);
        }
    }
}