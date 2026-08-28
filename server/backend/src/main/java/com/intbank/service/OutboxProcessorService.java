package com.intbank.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
public class OutboxProcessorService
{

    private static final Logger log = LoggerFactory.getLogger(OutboxProcessorService.class);
    private static final String INITIATED_TOPIC = TransferInitiatedEvent.EVENT_NAME;

    private final OutboxJpaRepository outboxRepo;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ProcessTransferUseCase processTransferUseCase;
    private final ObjectMapper objectMapper;
    private final boolean kafkaEnabled;

    public OutboxProcessorService(OutboxJpaRepository outboxRepo,
                                  KafkaTemplate<String, String> kafkaTemplate,
                                  ProcessTransferUseCase processTransferUseCase,
                                  ObjectMapper objectMapper,
                                  @Value("${app.kafka.enabled:true}") boolean kafkaEnabled)
    {
        this.outboxRepo = outboxRepo;
        this.kafkaTemplate = kafkaTemplate;
        this.processTransferUseCase = processTransferUseCase;
        this.objectMapper = objectMapper;
        this.kafkaEnabled = kafkaEnabled;
    }

    @Scheduled(fixedDelay = 5000)
    public void processOutbox()
    {
        List<OutboxJpaEntity> pending = outboxRepo.findTop100ByStatusAndRetryCountLessThanOrderByCreatedAtAsc("PENDING", 5);
        for (OutboxJpaEntity msg : pending) {
            try {
                if (kafkaEnabled) {
                    kafkaTemplate.send(msg.getTopic(), msg.getPartitionKey(), msg.getPayload()).get();
                    msg.setStatus("SENT");
                    outboxRepo.save(msg);
                    log.debug("Outbox message {} sent to topic {}", msg.getId(), msg.getTopic());
                } else {
                    deliverLocally(msg);
                }
            } catch (Exception e) {
                msg.setRetryCount(msg.getRetryCount() + 1);
                msg.setLastError(e.getMessage());
                if (msg.getRetryCount() >= msg.getMaxRetries()) {
                    msg.setStatus("DEAD");
                }
                outboxRepo.save(msg);
                log.error("Outbox message {} failed: {}", msg.getId(), e.getMessage());
            }
        }
    }

    // Kafka-optional mode: when no broker is available (e.g. Render PaaS), drive the
    // saga directly from the outbox instead of publishing to Kafka.
    private void deliverLocally(OutboxJpaEntity msg) throws Exception
    {
        if (INITIATED_TOPIC.equals(msg.getTopic())) {
            TransferInitiatedEvent event = objectMapper.readValue(msg.getPayload(), TransferInitiatedEvent.class);
            processTransferUseCase.execute(event);
        }
        // transfer.completed / transfer.failed have no local consumer; mark delivered.
        msg.setStatus("SENT");
        outboxRepo.save(msg);
        log.debug("Outbox message {} delivered locally (topic {})", msg.getId(), msg.getTopic());
    }

    @Transactional(readOnly = true)
    public Map<String, Long> getStats()
    {
        return Map.of(
                "total", outboxRepo.count(),
                "pending", outboxRepo.countByStatus("PENDING"),
                "sent", outboxRepo.countByStatus("SENT"),
                "dead", outboxRepo.countByStatusAndRetryCountGreaterThanEqual("DEAD", 5)
        );
    }

    @Transactional
    public int reprocessDead()
    {
        List<OutboxJpaEntity> dead = outboxRepo.findByStatusOrderByCreatedAtAsc("DEAD");
        int count = 0;
        for (OutboxJpaEntity msg : dead) {
            if (msg.getRetryCount() < msg.getMaxRetries()) {
                msg.setStatus("PENDING");
                msg.setRetryCount(0);
                outboxRepo.save(msg);
                count++;
            }
        }
        return count;
    }

    @Transactional
    public Map<String, Integer> processNow()
    {
        processOutbox();
        Map<String, Long> stats = getStats();
        return Map.of("processed", stats.get("sent").intValue(), "failed", stats.get("dead").intValue());
    }
}
