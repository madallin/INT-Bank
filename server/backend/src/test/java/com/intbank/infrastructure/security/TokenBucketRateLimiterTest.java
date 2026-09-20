package com.intbank.infrastructure.security;

import com.intbank.infrastructure.security.TokenBucketRateLimiter.RateLimitPolicy;
import com.intbank.infrastructure.security.TokenBucketRateLimiter.RateLimitResult;
import org.junit.jupiter.api.Test;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TokenBucketRateLimiterTest
{
    private static final long NANOS_PER_SECOND = 1_000_000_000L;

    private static final class TestClock
    {
        private final AtomicLong nanos = new AtomicLong(0L);
        private final AtomicLong epochSeconds = new AtomicLong(1_700_000_000L);

        private TokenBucketRateLimiter newLimiter()
        {
            return new TokenBucketRateLimiter(nanos::get, epochSeconds::get);
        }

        private void advanceSeconds(long seconds)
        {
            nanos.addAndGet(seconds * NANOS_PER_SECOND);
            epochSeconds.addAndGet(seconds);
        }

        private void advanceNanos(long nanosToAdvance)
        {
            nanos.addAndGet(nanosToAdvance);
        }
    }

    @Test
    void consumesDownToZero_thenRejects()
    {
        TestClock clock = new TestClock();
        TokenBucketRateLimiter limiter = clock.newLimiter();
        RateLimitPolicy policy = new RateLimitPolicy(3L, 1L, 0L);

        assertTrue(limiter.tryConsume("client-a", policy).isAllowed());
        assertTrue(limiter.tryConsume("client-a", policy).isAllowed());
        RateLimitResult third = limiter.tryConsume("client-a", policy);
        assertTrue(third.isAllowed());
        assertEquals(0L, third.availableTokens());

        RateLimitResult rejected = limiter.tryConsume("client-a", policy);
        assertFalse(rejected.isAllowed());
        assertEquals(0L, rejected.availableTokens());
        assertEquals(1L, rejected.retryAfterSeconds());
    }

    @Test
    void timeProgression_refillsTokensUpToCapacity()
    {
        TestClock clock = new TestClock();
        TokenBucketRateLimiter limiter = clock.newLimiter();
        RateLimitPolicy policy = new RateLimitPolicy(5L, 2L, 0L);

        for (int i = 0; i < 5; i++)
        {
            assertTrue(limiter.tryConsume("client-a", policy).isAllowed());
        }
        assertFalse(limiter.tryConsume("client-a", policy).isAllowed());

        clock.advanceSeconds(1L);
        RateLimitResult afterOneSecond = limiter.tryConsume("client-a", policy, 2L);
        assertTrue(afterOneSecond.isAllowed());
        assertEquals(0L, afterOneSecond.availableTokens());

        clock.advanceSeconds(10L);
        RateLimitResult afterLongWait = limiter.tryConsume("client-a", policy, 5L);
        assertTrue(afterLongWait.isAllowed());
        assertEquals(0L, afterLongWait.availableTokens());
        assertFalse(limiter.tryConsume("client-a", policy).isAllowed());
    }

    @Test
    void burstAllowance_permitsImmediateBurst()
    {
        TestClock clock = new TestClock();
        TokenBucketRateLimiter limiter = clock.newLimiter();
        RateLimitPolicy policy = new RateLimitPolicy(5L, 1L, 10L);

        RateLimitResult largeBurst = limiter.tryConsume("client-a", policy, 12L);
        assertTrue(largeBurst.isAllowed());
        assertEquals(3L, largeBurst.availableTokens());

        RateLimitResult remainder = limiter.tryConsume("client-a", policy, 3L);
        assertTrue(remainder.isAllowed());
        assertEquals(0L, remainder.availableTokens());

        assertFalse(limiter.tryConsume("client-a", policy).isAllowed());
    }

    @Test
    void retryAfterSeconds_matchesTimeToReplenishRequestedTokens()
    {
        TestClock clock = new TestClock();
        TokenBucketRateLimiter limiter = clock.newLimiter();
        RateLimitPolicy policy = new RateLimitPolicy(10L, 2L, 0L);

        limiter.tryConsume("client-a", policy, 10L);

        RateLimitResult needFive = limiter.tryConsume("client-a", policy, 5L);
        assertFalse(needFive.isAllowed());
        assertEquals(3L, needFive.retryAfterSeconds());

        RateLimitResult needOne = limiter.tryConsume("client-a", policy, 1L);
        assertFalse(needOne.isAllowed());
        assertEquals(1L, needOne.retryAfterSeconds());

        RateLimitPolicy noRefill = new RateLimitPolicy(10L, 0L, 0L);
        RateLimitResult never = limiter.tryConsume("client-b", noRefill, 10L);
        assertTrue(never.isAllowed());
        RateLimitResult stuck = limiter.tryConsume("client-b", noRefill, 1L);
        assertFalse(stuck.isAllowed());
        assertEquals(Long.MAX_VALUE, stuck.retryAfterSeconds());
    }

    @Test
    void reset_restoresBucket_andActiveClientCountTracksDistinctKeys()
    {
        TestClock clock = new TestClock();
        TokenBucketRateLimiter limiter = clock.newLimiter();
        RateLimitPolicy policy = new RateLimitPolicy(2L, 1L, 0L);

        limiter.tryConsume("client-a", policy, 2L);
        limiter.tryConsume("client-b", policy, 2L);
        assertEquals(2, limiter.getActiveClientCount());

        assertFalse(limiter.tryConsume("client-a", policy).isAllowed());

        limiter.reset("client-a");
        assertEquals(1, limiter.getActiveClientCount());

        limiter.tryConsume("client-a", policy);
        assertEquals(2, limiter.getActiveClientCount());
        assertTrue(limiter.tryConsume("client-a", policy).isAllowed());

        limiter.reset("missing-key");
        assertEquals(2, limiter.getActiveClientCount());
    }

    @Test
    void concurrentConsumption_conservesTokensExactly()
    {
        long capacity = 100L;
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(() -> 0L, () -> 1_700_000_000L);
        RateLimitPolicy policy = new RateLimitPolicy(capacity, 1L, 0L);

        int threadCount = 8;
        int attemptsPerThread = 25;
        int totalAttempts = threadCount * attemptsPerThread;

        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startGate = new CountDownLatch(1);
        CountDownLatch finishGate = new CountDownLatch(threadCount);
        AtomicInteger allowed = new AtomicInteger(0);
        AtomicInteger rejected = new AtomicInteger(0);
        AtomicReference<Throwable> failure = new AtomicReference<>(null);

        for (int t = 0; t < threadCount; t++)
        {
            executor.execute(() ->
            {
                try
                {
                    startGate.await();
                    for (int i = 0; i < attemptsPerThread; i++)
                    {
                        RateLimitResult result = limiter.tryConsume("shared-client", policy);
                        if (result.isAllowed())
                        {
                            allowed.incrementAndGet();
                        }
                        else
                        {
                            rejected.incrementAndGet();
                        }
                    }
                }
                catch (Throwable error)
                {
                    failure.compareAndSet(null, error);
                }
                finally
                {
                    finishGate.countDown();
                }
            });
        }

        startGate.countDown();
        boolean completed;
        try
        {
            completed = finishGate.await(30L, TimeUnit.SECONDS);
        }
        catch (InterruptedException interrupted)
        {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while waiting for concurrent workers", interrupted);
        }
        finally
        {
            executor.shutdownNow();
        }

        assertTrue(completed, "Concurrent workers did not finish in time");
        assertNull(failure.get(), "A concurrent worker threw an exception");
        assertEquals(capacity, allowed.get(), "Allowed consumes must equal initial tokens");
        assertEquals(totalAttempts - capacity, rejected.get(), "Rejected consumes must match");
        assertEquals(1, limiter.getActiveClientCount());
        assertEquals(0L, limiter.tryConsume("shared-client", policy).availableTokens());
    }

    @Test
    void fractionalRefill_accountsForSubSecondAccrual()
    {
        final TestClock clock = new TestClock();
        final TokenBucketRateLimiter limiter = clock.newLimiter();
        final RateLimitPolicy policy = new RateLimitPolicy(2L, 1L, 0L);

        final RateLimitResult drained = limiter.tryConsume("client-a", policy, 2L);
        assertTrue(drained.isAllowed());
        assertEquals(0L, drained.availableTokens());

        clock.advanceNanos(500_000_000L);
        final RateLimitResult halfSecond = limiter.tryConsume("client-a", policy, 1L);
        assertFalse(halfSecond.isAllowed());
        assertEquals(0L, halfSecond.availableTokens());
        assertEquals(1L, halfSecond.retryAfterSeconds());

        clock.advanceNanos(500_000_000L);
        final RateLimitResult fullSecond = limiter.tryConsume("client-a", policy, 1L);
        assertTrue(fullSecond.isAllowed());
        assertEquals(0L, fullSecond.availableTokens());
        assertFalse(limiter.tryConsume("client-a", policy).isAllowed());
    }

    @Test
    void fractionalRefill_nanosecondBoundaryIsExact()
    {
        final TestClock clock = new TestClock();
        final TokenBucketRateLimiter limiter = clock.newLimiter();
        final RateLimitPolicy policy = new RateLimitPolicy(1L, 1L, 0L);

        assertTrue(limiter.tryConsume("client-a", policy).isAllowed());

        clock.advanceNanos(999_999_999L);
        final RateLimitResult justShort = limiter.tryConsume("client-a", policy);
        assertFalse(justShort.isAllowed());
        assertEquals(0L, justShort.availableTokens());
        assertEquals(1L, justShort.retryAfterSeconds());

        clock.advanceNanos(1L);
        final RateLimitResult exactlyRefilled = limiter.tryConsume("client-a", policy);
        assertTrue(exactlyRefilled.isAllowed());
        assertEquals(0L, exactlyRefilled.availableTokens());
    }

    @Test
    void concurrentContention_conservesTokensAndAccountsEveryAttempt()
    {
        final long capacity = 64L;
        final TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(() -> 0L, () -> 1_700_000_000L);
        final RateLimitPolicy policy = new RateLimitPolicy(capacity, 1L, 0L);

        final int threadCount = 16;
        final int attemptsPerThread = 16;
        final int totalAttempts = threadCount * attemptsPerThread;

        final ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        final CountDownLatch startGate = new CountDownLatch(1);
        final CountDownLatch finishGate = new CountDownLatch(threadCount);
        final AtomicInteger allowed = new AtomicInteger(0);
        final AtomicInteger rejected = new AtomicInteger(0);
        final AtomicReference<Throwable> failure = new AtomicReference<>(null);

        for (int t = 0; t < threadCount; t++)
        {
            executor.execute(() ->
            {
                try
                {
                    startGate.await();
                    for (int i = 0; i < attemptsPerThread; i++)
                    {
                        if (limiter.tryConsume("contended-client", policy).isAllowed())
                        {
                            allowed.incrementAndGet();
                        }
                        else
                        {
                            rejected.incrementAndGet();
                        }
                    }
                }
                catch (Throwable error)
                {
                    failure.compareAndSet(null, error);
                }
                finally
                {
                    finishGate.countDown();
                }
            });
        }

        startGate.countDown();
        boolean completed;
        try
        {
            completed = finishGate.await(30L, TimeUnit.SECONDS);
        }
        catch (InterruptedException interrupted)
        {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while waiting for concurrent workers", interrupted);
        }
        finally
        {
            executor.shutdownNow();
        }

        assertTrue(completed, "Concurrent workers did not finish in time");
        assertNull(failure.get(), "A concurrent worker threw an exception");
        assertEquals(totalAttempts, allowed.get() + rejected.get(), "Every attempt must be accounted exactly once");
        assertEquals(capacity, allowed.get(), "Allowed consumes must equal the initial scaled capacity");
        assertEquals(totalAttempts - capacity, rejected.get(), "Rejected consumes must match the shortfall");
        assertEquals(1, limiter.getActiveClientCount());
        assertEquals(0L, limiter.tryConsume("contended-client", policy).availableTokens());
    }
}
