package com.intbank.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.ValidationException;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.header.Header;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.dao.TransientDataAccessException;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.validation.BindException;

import java.io.IOException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeoutException;

@Service
public class KafkaDlqRecoveryService
{

    private static final Logger log = LoggerFactory.getLogger(KafkaDlqRecoveryService.class);

    public static final String DEAD_LETTER_TOPIC = "transfer.dlq";

    public static final String HEADER_ORIGINAL_TOPIC = "original-topic";
    public static final String HEADER_ORIGINAL_PARTITION = "original-partition";
    public static final String HEADER_ORIGINAL_OFFSET = "original-offset";
    public static final String HEADER_EXCEPTION_CLASS = "exception-class";
    public static final String HEADER_ERROR_MESSAGE = "error-message";
    public static final String HEADER_FAILED_AT = "failed-at";
    public static final String HEADER_RETRY_ATTEMPT = "retry-attempt";

    public static final long DEFAULT_BASE_BACKOFF_MILLIS = 1000L;
    public static final long DEFAULT_MAX_BACKOFF_MILLIS = 30000L;

    private static final int MAX_CAUSE_DEPTH = 20;

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final ObjectMapper objectMapper;

    public KafkaDlqRecoveryService(KafkaTemplate<String, Object> kafkaTemplate, ObjectMapper objectMapper)
    {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
    }

    public record DlqEnvelope(
            String originalTopic,
            int originalPartition,
            long originalOffset,
            String payload,
            String exceptionClass,
            String errorMessage,
            Instant failedAt)
    {
    }

    public record RetryDecision(boolean retryable, long backoffMillis)
    {
    }

    public boolean isRetryable(Throwable throwable)
    {
        if (throwable == null)
        {
            return false;
        }
        List<Throwable> chain = causeChain(throwable);
        for (Throwable candidate : chain)
        {
            if (isNonRetryable(candidate))
            {
                return false;
            }
        }
        for (Throwable candidate : chain)
        {
            if (isTransient(candidate))
            {
                return true;
            }
        }
        return false;
    }

    public long computeBackoffMillis(int attempt, long baseMillis, long maxMillis)
    {
        if (baseMillis <= 0L || maxMillis <= 0L)
        {
            return 0L;
        }
        int exponent = Math.max(attempt, 0);
        long delay = baseMillis;
        for (int i = 0; i < exponent; i++)
        {
            if (delay >= maxMillis || delay > Long.MAX_VALUE / 2L)
            {
                return maxMillis;
            }
            delay *= 2L;
        }
        return Math.min(delay, maxMillis);
    }

    public DlqEnvelope toEnvelope(String topic, int partition, long offset, Object payload, Throwable throwable)
    {
        String exceptionClass = throwable == null ? null : throwable.getClass().getName();
        String errorMessage = throwable == null ? null : throwable.getMessage();
        return new DlqEnvelope(topic, partition, offset, serializePayload(payload), exceptionClass, errorMessage,
                Instant.now());
    }

    public void routeToDeadLetter(DlqEnvelope envelope)
    {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("originalTopic", envelope.originalTopic());
        body.put("originalPartition", envelope.originalPartition());
        body.put("originalOffset", envelope.originalOffset());
        body.put("payload", envelope.payload());
        body.put("exceptionClass", envelope.exceptionClass());
        body.put("errorMessage", envelope.errorMessage());
        body.put("failedAt", envelope.failedAt() == null ? null : envelope.failedAt().toString());

        String key = envelope.originalTopic() + ":" + envelope.originalPartition() + ":" + envelope.originalOffset();
        ProducerRecord<String, Object> deadLetter = new ProducerRecord<>(
                DEAD_LETTER_TOPIC, envelope.originalPartition(), key, body);
        addHeader(deadLetter, HEADER_ORIGINAL_TOPIC, envelope.originalTopic());
        addHeader(deadLetter, HEADER_ORIGINAL_PARTITION, Integer.toString(envelope.originalPartition()));
        addHeader(deadLetter, HEADER_ORIGINAL_OFFSET, Long.toString(envelope.originalOffset()));
        addHeader(deadLetter, HEADER_EXCEPTION_CLASS, envelope.exceptionClass());
        addHeader(deadLetter, HEADER_ERROR_MESSAGE, envelope.errorMessage());
        addHeader(deadLetter, HEADER_FAILED_AT, envelope.failedAt() == null ? null : envelope.failedAt().toString());

        CompletableFuture<?> future = kafkaTemplate.send(deadLetter);
        future.whenComplete((result, error) -> {
            if (error != null)
            {
                log.error("Failed to publish poison pill to {} for {}:{}:{}", DEAD_LETTER_TOPIC,
                        envelope.originalTopic(), envelope.originalPartition(), envelope.originalOffset(), error);
            }
            else
            {
                log.warn("Routed poison pill from {}:{}:{} to {}", envelope.originalTopic(),
                        envelope.originalPartition(), envelope.originalOffset(), DEAD_LETTER_TOPIC);
            }
        });
    }

    public RetryDecision handle(ConsumerRecord<String, Object> record, Exception error)
    {
        if (isRetryable(error))
        {
            int attempt = resolveRetryAttempt(record);
            long backoff = computeBackoffMillis(attempt, DEFAULT_BASE_BACKOFF_MILLIS, DEFAULT_MAX_BACKOFF_MILLIS);
            log.warn("Transient failure on {}:{}:{} (attempt {}); retry allowed after {}ms",
                    record.topic(), record.partition(), record.offset(), attempt, backoff);
            return new RetryDecision(true, backoff);
        }

        DlqEnvelope envelope = toEnvelope(record.topic(), record.partition(), record.offset(), record.value(), error);
        routeToDeadLetter(envelope);
        log.error("Non-retryable poison pill on {}:{}:{} ({}) routed to {}",
                record.topic(), record.partition(), record.offset(),
                error == null ? "unknown" : error.getClass().getName(), DEAD_LETTER_TOPIC);
        return new RetryDecision(false, 0L);
    }

    private boolean isNonRetryable(Throwable throwable)
    {
        return throwable instanceof JsonProcessingException
                || throwable instanceof IllegalArgumentException
                || throwable instanceof ValidationException
                || throwable instanceof BindException;
    }

    private boolean isTransient(Throwable throwable)
    {
        return throwable instanceof SocketTimeoutException
                || throwable instanceof ConnectException
                || throwable instanceof TimeoutException
                || throwable instanceof TransientDataAccessException
                || throwable instanceof PessimisticLockingFailureException
                || throwable instanceof QueryTimeoutException
                || throwable instanceof DataAccessResourceFailureException
                || throwable instanceof IOException;
    }

    private List<Throwable> causeChain(Throwable throwable)
    {
        List<Throwable> chain = new ArrayList<>();
        Throwable current = throwable;
        int depth = 0;
        while (current != null && depth < MAX_CAUSE_DEPTH)
        {
            chain.add(current);
            Throwable next = current.getCause();
            if (next == current)
            {
                break;
            }
            current = next;
            depth++;
        }
        return chain;
    }

    private int resolveRetryAttempt(ConsumerRecord<String, Object> record)
    {
        Header header = record.headers().lastHeader(HEADER_RETRY_ATTEMPT);
        if (header == null || header.value() == null)
        {
            return 0;
        }
        try
        {
            return Math.max(0, Integer.parseInt(new String(header.value(), StandardCharsets.UTF_8)));
        }
        catch (NumberFormatException ex)
        {
            return 0;
        }
    }

    private String serializePayload(Object payload)
    {
        if (payload == null)
        {
            return null;
        }
        if (payload instanceof String text)
        {
            return text;
        }
        try
        {
            return objectMapper.writeValueAsString(payload);
        }
        catch (JsonProcessingException ex)
        {
            return String.valueOf(payload);
        }
    }

    private void addHeader(ProducerRecord<String, Object> record, String name, String value)
    {
        if (value != null)
        {
            record.headers().add(name, value.getBytes(StandardCharsets.UTF_8));
        }
    }
}
