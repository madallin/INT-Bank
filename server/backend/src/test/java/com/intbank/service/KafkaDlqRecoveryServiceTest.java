package com.intbank.service;

import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.service.KafkaDlqRecoveryService.DlqEnvelope;
import com.intbank.service.KafkaDlqRecoveryService.RetryDecision;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.header.Header;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.ArgumentMatchers;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.kafka.core.KafkaTemplate;

import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeoutException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class KafkaDlqRecoveryServiceTest
{

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Captor
    private ArgumentCaptor<ProducerRecord<String, Object>> recordCaptor;

    private ObjectMapper objectMapper;
    private KafkaDlqRecoveryService service;

    @BeforeEach
    void setUp()
    {
        objectMapper = new ObjectMapper();
        service = new KafkaDlqRecoveryService(kafkaTemplate, objectMapper);
        lenient().doReturn(CompletableFuture.completedFuture(null))
                .when(kafkaTemplate).send(ArgumentMatchers.<ProducerRecord<String, Object>>any());
    }

    @Test
    void transientNetworkAndDatabaseErrorsAreRetryable()
    {
        assertTrue(service.isRetryable(new SocketTimeoutException("socket timed out")));
        assertTrue(service.isRetryable(new ConnectException("connection refused")));
        assertTrue(service.isRetryable(new TimeoutException("timed out")));
        assertTrue(service.isRetryable(new CannotAcquireLockException("row locked")));
        assertTrue(service.isRetryable(new PessimisticLockingFailureException("lock failure")));
        assertTrue(service.isRetryable(new QueryTimeoutException("query timeout")));
        assertTrue(service.isRetryable(new DataAccessResourceFailureException("resource down")));
    }

    @Test
    void wrappedTransientErrorIsStillRetryable()
    {
        Throwable wrapped = new RuntimeException("processing failed",
                new SocketTimeoutException("socket timed out"));

        assertTrue(service.isRetryable(wrapped));
    }

    @Test
    void poisonPillsAreNotRetryable()
    {
        assertFalse(service.isRetryable(new JsonParseException((JsonParser) null, "malformed json")));
        assertFalse(service.isRetryable(JsonMappingException.from((JsonParser) null, "invalid schema")));
        assertFalse(service.isRetryable(new IllegalArgumentException("invalid field")));
        assertFalse(service.isRetryable(new jakarta.validation.ValidationException("schema violation")));
    }

    @Test
    void wrappedPoisonPillIsNotRetryable()
    {
        Throwable wrapped = new RuntimeException("processing failed",
                new JsonParseException((JsonParser) null, "malformed json"));

        assertFalse(service.isRetryable(wrapped));
    }

    @Test
    void computeBackoffFollowsExponentialSequenceAndCaps()
    {
        assertEquals(100L, service.computeBackoffMillis(0, 100L, 1000L));
        assertEquals(200L, service.computeBackoffMillis(1, 100L, 1000L));
        assertEquals(400L, service.computeBackoffMillis(2, 100L, 1000L));
        assertEquals(800L, service.computeBackoffMillis(3, 100L, 1000L));
        assertEquals(1000L, service.computeBackoffMillis(4, 100L, 1000L));
        assertEquals(1000L, service.computeBackoffMillis(5, 100L, 1000L));
        assertEquals(1000L, service.computeBackoffMillis(64, 100L, 1000L));
    }

    @Test
    void computeBackoffIsDefensiveForInvalidInputs()
    {
        assertEquals(100L, service.computeBackoffMillis(-5, 100L, 1000L));
        assertEquals(0L, service.computeBackoffMillis(3, 0L, 1000L));
        assertEquals(0L, service.computeBackoffMillis(3, 100L, 0L));
    }

    @Test
    void poisonPillIsRoutedToDeadLetterTopicWithMetadata() throws Exception
    {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("amount", 150);
        payload.put("currency", "EUR");
        ConsumerRecord<String, Object> record = new ConsumerRecord<>("transfer.initiated", 3, 42L, "key-42", payload);

        RetryDecision decision = service.handle(record, new JsonParseException((JsonParser) null, "malformed json"));

        assertFalse(decision.retryable());
        assertEquals(0L, decision.backoffMillis());

        verify(kafkaTemplate).send(recordCaptor.capture());
        ProducerRecord<String, Object> sent = recordCaptor.getValue();

        assertEquals(KafkaDlqRecoveryService.DEAD_LETTER_TOPIC, sent.topic());
        assertEquals(3, sent.partition());
        assertEquals("transfer.initiated:3:42", sent.key());

        assertEquals("transfer.initiated", headerValue(sent, KafkaDlqRecoveryService.HEADER_ORIGINAL_TOPIC));
        assertEquals("3", headerValue(sent, KafkaDlqRecoveryService.HEADER_ORIGINAL_PARTITION));
        assertEquals("42", headerValue(sent, KafkaDlqRecoveryService.HEADER_ORIGINAL_OFFSET));
        assertEquals(JsonParseException.class.getName(),
                headerValue(sent, KafkaDlqRecoveryService.HEADER_EXCEPTION_CLASS));
        assertEquals("malformed json", headerValue(sent, KafkaDlqRecoveryService.HEADER_ERROR_MESSAGE));
        assertNotNull(headerValue(sent, KafkaDlqRecoveryService.HEADER_FAILED_AT));

        assertTrue(sent.value() instanceof Map<?, ?>);
        Map<?, ?> body = (Map<?, ?>) sent.value();
        assertEquals("transfer.initiated", body.get("originalTopic"));
        assertEquals(3, body.get("originalPartition"));
        assertEquals(42L, body.get("originalOffset"));
        assertEquals(objectMapper.writeValueAsString(payload), body.get("payload"));
        assertEquals(JsonParseException.class.getName(), body.get("exceptionClass"));
    }

    @Test
    void retryableErrorDoesNotSendToDeadLetter()
    {
        ConsumerRecord<String, Object> record = new ConsumerRecord<>("transfer.initiated", 0, 7L, "key-7", "payload");

        RetryDecision decision = service.handle(record, new SocketTimeoutException("socket timed out"));

        assertTrue(decision.retryable());
        assertEquals(KafkaDlqRecoveryService.DEFAULT_BASE_BACKOFF_MILLIS, decision.backoffMillis());
        verify(kafkaTemplate, never()).send(ArgumentMatchers.<ProducerRecord<String, Object>>any());
    }

    @Test
    void retryAttemptHeaderDrivesBackoff()
    {
        ConsumerRecord<String, Object> record = new ConsumerRecord<>("transfer.initiated", 0, 8L, "key-8", "payload");
        record.headers().add(KafkaDlqRecoveryService.HEADER_RETRY_ATTEMPT, "3".getBytes(StandardCharsets.UTF_8));

        RetryDecision decision = service.handle(record, new TimeoutException("timed out"));

        assertTrue(decision.retryable());
        assertEquals(service.computeBackoffMillis(3, KafkaDlqRecoveryService.DEFAULT_BASE_BACKOFF_MILLIS,
                KafkaDlqRecoveryService.DEFAULT_MAX_BACKOFF_MILLIS), decision.backoffMillis());
    }

    @Test
    void toEnvelopeCapturesFailureMetadataAndSerializesPayload() throws Exception
    {
        Map<String, Object> payload = Map.of("transferId", "abc");
        Instant before = Instant.now();

        DlqEnvelope envelope = service.toEnvelope("transfer.initiated", 1, 99L, payload,
                new JsonParseException((JsonParser) null, "bad payload"));

        Instant after = Instant.now();
        assertEquals("transfer.initiated", envelope.originalTopic());
        assertEquals(1, envelope.originalPartition());
        assertEquals(99L, envelope.originalOffset());
        assertEquals(objectMapper.writeValueAsString(payload), envelope.payload());
        assertEquals(JsonParseException.class.getName(), envelope.exceptionClass());
        assertEquals("bad payload", envelope.errorMessage());
        assertNotNull(envelope.failedAt());
        assertFalse(envelope.failedAt().isBefore(before));
        assertFalse(envelope.failedAt().isAfter(after));
    }

    private String headerValue(ProducerRecord<String, Object> record, String name)
    {
        Header header = record.headers().lastHeader(name);
        return header == null ? null : new String(header.value(), StandardCharsets.UTF_8);
    }
}
