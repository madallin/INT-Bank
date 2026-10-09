package com.intbank.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * The daily limit is enforced with an atomic counter (Redis INCRBY), so parallel transfers
 * cannot all pass a check that each one alone would have failed.
 */
class AmlDailyLimitTest
{

    private final ConcurrentHashMap<String, AtomicLong> counters = new ConcurrentHashMap<>();
    private AmlVelocityService aml;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp()
    {
        RedisTemplate<String, String> redis = mock(RedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        // Behaves like Redis INCR/INCRBY/DECRBY: atomic per key.
        when(ops.increment(anyString())).thenAnswer(i -> counter(i.getArgument(0)).incrementAndGet());
        when(ops.increment(anyString(), anyLong())).thenAnswer(i -> counter(i.getArgument(0)).addAndGet(i.getArgument(1)));
        when(ops.decrement(anyString(), anyLong())).thenAnswer(i -> counter(i.getArgument(0)).addAndGet(-(long) i.getArgument(1)));
        when(redis.getExpire(anyString())).thenReturn(-1L);
        aml = new AmlVelocityService(redis);
    }

    @Test
    void parallelTransfersCannotExceedTheDailyLimitTogether() throws Exception
    {
        // Five simultaneous 15,000 RON transfers against a 50,000 RON daily limit: each one alone
        // fits, together they do not. Exactly three may pass (45,000), whatever the interleaving.
        int threads = 5;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<AmlVelocityService.RiskAssessment>> results = new ArrayList<>();
        for (int i = 0; i < threads; i++)
        {
            results.add(pool.submit(() -> {
                start.await();
                return aml.evaluateTransfer(7L, new BigDecimal("15000.00"), "RON").assessment();
            }));
        }
        start.countDown();
        int passed = 0;
        for (var result : results)
        {
            if (result.get() != AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED) passed++;
        }
        pool.shutdown();

        assertEquals(3, passed);
        assertEquals(4_500_000L, counter("aml:daily:7:RON").get(), "only accepted amounts stay counted");
    }

    @Test
    void theRejectedAmountIsNotCounted()
    {
        assertNotEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(7L, new BigDecimal("49000"), "RON").assessment());
        assertEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(7L, new BigDecimal("1000.01"), "RON").assessment());
        assertEquals(4_900_000L, counter("aml:daily:7:RON").get(), "the refused 1,000.01 is rolled back");
        assertNotEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(7L, new BigDecimal("1000.00"), "RON").assessment(), "exactly the limit is allowed");
    }

    @Test
    void limitsArePerCurrency()
    {
        assertEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(8L, new BigDecimal("10000.01"), "EUR").assessment(), "EUR limit is 10,000");
        assertNotEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(8L, new BigDecimal("10000.01"), "RON").assessment(), "RON counts separately");
        assertEquals(AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED,
                aml.evaluateTransfer(9L, new BigDecimal("9000"), "CHF").assessment(), "unknown currency gets the strictest limit");
    }

    private AtomicLong counter(String key)
    {
        return counters.computeIfAbsent(key, k -> new AtomicLong());
    }
}
