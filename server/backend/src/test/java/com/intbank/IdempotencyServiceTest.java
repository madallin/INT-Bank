package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.infrastructure.persistence.entity.IdempotencyRecordJpaEntity;
import com.intbank.infrastructure.persistence.repository.IdempotencyJpaRepository;
import com.intbank.service.IdempotencyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class IdempotencyServiceTest
{

    @Mock
    private IdempotencyJpaRepository idempotencyRepo;

    @Mock
    private RedisTemplate<String, String> redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private ObjectMapper objectMapper = new ObjectMapper();
    private IdempotencyService idempotencyService;

    @BeforeEach
    void setUp()
    {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        idempotencyService = new IdempotencyService(idempotencyRepo, redisTemplate, objectMapper);
    }

    @Test
    void testFirstRequest_ShouldProceed()
    {
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        when(idempotencyRepo.findByIdempotencyKey("key-123")).thenReturn(Optional.empty());

        String hash = IdempotencyService.hashRequest(BigDecimal.valueOf(100), "RON", "RO1", "RO2", "Reason");
        IdempotencyService.Decision decision = idempotencyService.beginOrGet("key-123", 1L, hash);

        assertEquals(IdempotencyService.Outcome.PROCEED, decision.outcome());
        verify(idempotencyRepo).save(any(IdempotencyRecordJpaEntity.class));
    }

    @Test
    void testDuplicateCompletedRequest_ShouldReturnCached()
    {
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);

        String hash = IdempotencyService.hashRequest(BigDecimal.valueOf(100), "RON", "RO1", "RO2", "Reason");
        IdempotencyRecordJpaEntity rec = new IdempotencyRecordJpaEntity();
        rec.setIdempotencyKey("key-123");
        rec.setRequestHash(hash);
        rec.setStatus("COMPLETED");
        rec.setResponsePayload("{\"status\":\"ACCEPTED\",\"trackingId\":\"tx-1\"}");

        when(idempotencyRepo.findByIdempotencyKey("key-123")).thenReturn(Optional.of(rec));

        IdempotencyService.Decision decision = idempotencyService.beginOrGet("key-123", 1L, hash);

        assertEquals(IdempotencyService.Outcome.DUPLICATE_COMPLETED, decision.outcome());
        assertNotNull(decision.cachedResponsePayload());
        assertTrue(decision.cachedResponsePayload().contains("tx-1"));
    }

    @Test
    void testInFlightConcurrentRequest_ShouldReturnDuplicateInProgress()
    {
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(false);

        String hash = IdempotencyService.hashRequest(BigDecimal.valueOf(100), "RON", "RO1", "RO2", "Reason");
        IdempotencyService.Decision decision = idempotencyService.beginOrGet("key-123", 1L, hash);

        assertEquals(IdempotencyService.Outcome.DUPLICATE_IN_PROGRESS, decision.outcome());
    }
}
