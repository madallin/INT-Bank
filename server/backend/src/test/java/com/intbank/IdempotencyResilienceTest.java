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
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
public class IdempotencyResilienceTest
{

    @Mock
    private IdempotencyJpaRepository idempotencyRepo;

    @Mock
    private RedisTemplate<String, String> redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private IdempotencyService idempotencyService;

    private static final String CURRENCY = "RON";
    private static final String FROM_IBAN = "RO49AAAA1B31007593840000";
    private static final String TO_IBAN = "RO49BBBB1B31007593840001";
    private static final String REASON = "rent-october";

    @BeforeEach
    void setUp()
    {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        idempotencyService = new IdempotencyService(idempotencyRepo, redisTemplate, objectMapper);
    }

    private record TransferReceipt(String status, String trackingId)
    {
    }

    private static final class Account
    {
        private BigDecimal balance;
        private final AtomicInteger debitCount = new AtomicInteger();

        Account(BigDecimal openingBalance)
        {
            this.balance = openingBalance;
        }

        void debit(BigDecimal amount)
        {
            this.balance = this.balance.subtract(amount);
            this.debitCount.incrementAndGet();
        }

        BigDecimal balance()
        {
            return this.balance;
        }

        int debitCount()
        {
            return this.debitCount.get();
        }
    }

    @Test
    void networkDropRetry()
    {
        final String key = "idem-retry-0001";
        final Long userId = 42L;
        final BigDecimal amount = new BigDecimal("250.00");
        final String hash = IdempotencyService.hashRequest(amount, CURRENCY, FROM_IBAN, TO_IBAN, REASON);
        final Account account = new Account(new BigDecimal("1000.00"));
        final TransferReceipt receipt = new TransferReceipt("ACCEPTED", "tx-retry-1");

        final Map<String, IdempotencyRecordJpaEntity> store = new ConcurrentHashMap<>();
        final Map<String, Boolean> locks = new ConcurrentHashMap<>();

        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class)))
                .thenAnswer(invocation -> locks.putIfAbsent(invocation.getArgument(0), Boolean.TRUE) == null);
        when(redisTemplate.delete(anyString()))
                .thenAnswer(invocation -> locks.remove(invocation.getArgument(0)) != null);
        when(idempotencyRepo.findByIdempotencyKey(anyString()))
                .thenAnswer(invocation -> Optional.ofNullable(store.get(invocation.getArgument(0))));
        when(idempotencyRepo.save(any(IdempotencyRecordJpaEntity.class)))
                .thenAnswer(invocation ->
                {
                    final IdempotencyRecordJpaEntity entity = invocation.getArgument(0);
                    store.put(entity.getIdempotencyKey(), entity);
                    return entity;
                });

        int executedDebits = 0;

        final IdempotencyService.Decision first = idempotencyService.beginOrGet(key, userId, hash);
        assertEquals(IdempotencyService.Outcome.PROCEED, first.outcome());
        if (first.outcome() == IdempotencyService.Outcome.PROCEED)
        {
            account.debit(amount);
            executedDebits++;
            idempotencyService.complete(key, receipt);
        }

        final IdempotencyService.Decision retry = idempotencyService.beginOrGet(key, userId, hash);
        assertEquals(IdempotencyService.Outcome.DUPLICATE_COMPLETED, retry.outcome());
        assertNotNull(retry.cachedResponsePayload());
        assertTrue(retry.cachedResponsePayload().contains("tx-retry-1"));
        if (retry.outcome() == IdempotencyService.Outcome.PROCEED)
        {
            account.debit(amount);
            executedDebits++;
        }

        assertEquals(1, executedDebits);
        assertEquals(1, account.debitCount());
        assertEquals(new BigDecimal("750.00"), account.balance());
    }

    @Test
    void inFlightConcurrentConflict() throws Exception
    {
        final String key = "idem-inflight-0002";
        final Long userId = 7L;
        final BigDecimal amount = new BigDecimal("100.00");
        final String hash = IdempotencyService.hashRequest(amount, CURRENCY, FROM_IBAN, TO_IBAN, REASON);

        final AtomicBoolean lockTaken = new AtomicBoolean(false);
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class)))
                .thenAnswer(invocation -> !lockTaken.getAndSet(true));
        when(idempotencyRepo.findByIdempotencyKey(anyString())).thenReturn(Optional.empty());

        final CountDownLatch ready = new CountDownLatch(2);
        final CountDownLatch start = new CountDownLatch(1);
        final Callable<IdempotencyService.Decision> task = () ->
        {
            ready.countDown();
            if (!start.await(5, TimeUnit.SECONDS))
            {
                throw new IllegalStateException("concurrent start latch timed out");
            }
            return idempotencyService.beginOrGet(key, userId, hash);
        };

        final ExecutorService pool = Executors.newFixedThreadPool(2);
        try
        {
            final Future<IdempotencyService.Decision> first = pool.submit(task);
            final Future<IdempotencyService.Decision> second = pool.submit(task);
            assertTrue(ready.await(5, TimeUnit.SECONDS));
            start.countDown();

            final List<IdempotencyService.Outcome> outcomes = new ArrayList<>();
            outcomes.add(first.get(5, TimeUnit.SECONDS).outcome());
            outcomes.add(second.get(5, TimeUnit.SECONDS).outcome());

            assertEquals(1, outcomes.stream().filter(o -> o == IdempotencyService.Outcome.PROCEED).count());
            assertEquals(1, outcomes.stream()
                    .filter(o -> o == IdempotencyService.Outcome.DUPLICATE_IN_PROGRESS).count());
        }
        finally
        {
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(5, TimeUnit.SECONDS));
        }
    }

    @Test
    void payloadTamperAttack()
    {
        final String key = "idem-tamper-0003";
        final Long userId = 99L;
        final BigDecimal amount = new BigDecimal("500.00");
        final String originalHash = IdempotencyService.hashRequest(amount, CURRENCY, FROM_IBAN, TO_IBAN, REASON);

        final IdempotencyRecordJpaEntity completed = new IdempotencyRecordJpaEntity();
        completed.setIdempotencyKey(key);
        completed.setUserId(userId);
        completed.setRequestHash(originalHash);
        completed.setStatus("COMPLETED");
        completed.setResponsePayload("{\"status\":\"ACCEPTED\",\"trackingId\":\"tx-original\"}");

        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        when(idempotencyRepo.findByIdempotencyKey(key)).thenReturn(Optional.of(completed));

        final String alteredAmountHash =
                IdempotencyService.hashRequest(new BigDecimal("999.00"), CURRENCY, FROM_IBAN, TO_IBAN, REASON);
        final String alteredRecipientHash =
                IdempotencyService.hashRequest(amount, CURRENCY, FROM_IBAN, "RO49CCCC1B31007593840099", REASON);
        final String alteredCurrencyHash =
                IdempotencyService.hashRequest(amount, "EUR", FROM_IBAN, TO_IBAN, REASON);

        assertEquals(originalHash, IdempotencyService.hashRequest(amount, CURRENCY, FROM_IBAN, TO_IBAN, REASON));
        assertTrue(originalHash.matches("[0-9a-f]{64}"));
        assertTrue(!originalHash.equals(alteredAmountHash));
        assertTrue(!originalHash.equals(alteredRecipientHash));
        assertTrue(!originalHash.equals(alteredCurrencyHash));

        assertThrows(IllegalStateException.class,
                () -> idempotencyService.beginOrGet(key, userId, alteredAmountHash));
        assertThrows(IllegalStateException.class,
                () -> idempotencyService.beginOrGet(key, userId, alteredRecipientHash));
        assertThrows(IllegalStateException.class,
                () -> idempotencyService.beginOrGet(key, userId, alteredCurrencyHash));
    }
}
