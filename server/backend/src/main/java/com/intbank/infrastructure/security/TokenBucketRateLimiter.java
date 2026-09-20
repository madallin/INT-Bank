package com.intbank.infrastructure.security;

import java.time.Instant;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

public class TokenBucketRateLimiter
{
    public record RateLimitPolicy(long capacity, long refillTokensPerSecond, long burstAllowance)
    {
    }

    public record RateLimitResult(boolean isAllowed, long availableTokens, long retryAfterSeconds, long resetTimeEpochSeconds)
    {
    }

    private static final long NANOS_PER_SECOND = 1_000_000_000L;

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();
    private final Supplier<Long> nanoTimeSupplier;
    private final Supplier<Long> epochSecondSupplier;

    public TokenBucketRateLimiter(Supplier<Long> nanoTimeSupplier, Supplier<Long> epochSecondSupplier)
    {
        this.nanoTimeSupplier = Objects.requireNonNull(nanoTimeSupplier, "nanoTimeSupplier");
        this.epochSecondSupplier = Objects.requireNonNull(epochSecondSupplier, "epochSecondSupplier");
    }

    public TokenBucketRateLimiter()
    {
        this(System::nanoTime, () -> Instant.now().getEpochSecond());
    }

    public RateLimitResult tryConsume(String clientKey, RateLimitPolicy policy)
    {
        return tryConsume(clientKey, policy, 1L);
    }

    public RateLimitResult tryConsume(String clientKey, RateLimitPolicy policy, long tokensToConsume)
    {
        Objects.requireNonNull(clientKey, "clientKey");
        Objects.requireNonNull(policy, "policy");

        long now = nanoTimeSupplier.get();
        long epochSecond = epochSecondSupplier.get();
        long capacityScaled = mulSaturating(policy.capacity(), NANOS_PER_SECOND);
        long initialScaled = mulSaturating(addSaturating(policy.capacity(), policy.burstAllowance()), NANOS_PER_SECOND);

        Bucket bucket = buckets.computeIfAbsent(clientKey, key -> new Bucket(initialScaled, now));
        long refillRate = policy.refillTokensPerSecond();

        synchronized (bucket)
        {
            bucket.refill(now, refillRate, capacityScaled);

            if (tokensToConsume <= 0L)
            {
                return new RateLimitResult(true, bucket.availableTokens(), 0L, resetTimeEpochSeconds(bucket, epochSecond, refillRate, capacityScaled));
            }

            long neededScaled = mulSaturating(tokensToConsume, NANOS_PER_SECOND);
            if (bucket.tokensScaled >= neededScaled)
            {
                bucket.tokensScaled -= neededScaled;
                return new RateLimitResult(true, bucket.availableTokens(), 0L, resetTimeEpochSeconds(bucket, epochSecond, refillRate, capacityScaled));
            }

            long deficitScaled = neededScaled - bucket.tokensScaled;
            long retryAfterSeconds;
            if (refillRate <= 0L)
            {
                retryAfterSeconds = Long.MAX_VALUE;
            }
            else
            {
                long neededNanos = ceilDiv(deficitScaled, refillRate);
                retryAfterSeconds = ceilDiv(neededNanos, NANOS_PER_SECOND);
            }

            return new RateLimitResult(false, bucket.availableTokens(), retryAfterSeconds, resetTimeEpochSeconds(bucket, epochSecond, refillRate, capacityScaled));
        }
    }

    public void reset(String clientKey)
    {
        Objects.requireNonNull(clientKey, "clientKey");
        buckets.remove(clientKey);
    }

    public int getActiveClientCount()
    {
        return buckets.size();
    }

    private static long resetTimeEpochSeconds(Bucket bucket, long epochSecond, long refillRate, long capacityScaled)
    {
        long deficitScaled = capacityScaled - bucket.tokensScaled;
        if (deficitScaled <= 0L)
        {
            return epochSecond;
        }
        if (refillRate <= 0L)
        {
            return Long.MAX_VALUE;
        }
        long neededNanos = ceilDiv(deficitScaled, refillRate);
        long seconds = ceilDiv(neededNanos, NANOS_PER_SECOND);
        return addSaturating(epochSecond, seconds);
    }

    private static long ceilDiv(long dividend, long divisor)
    {
        long quotient = dividend / divisor;
        if (dividend % divisor != 0L)
        {
            quotient++;
        }
        return quotient;
    }

    private static long addSaturating(long a, long b)
    {
        long sum = a + b;
        if (sum < 0L)
        {
            return Long.MAX_VALUE;
        }
        return sum;
    }

    private static long mulSaturating(long a, long b)
    {
        if (a == 0L || b == 0L)
        {
            return 0L;
        }
        long product = a * b;
        if (product / a != b)
        {
            return Long.MAX_VALUE;
        }
        return product;
    }

    private static final class Bucket
    {
        private long tokensScaled;
        private long lastRefillNanos;

        private Bucket(long initialTokensScaled, long nowNanos)
        {
            this.tokensScaled = initialTokensScaled < 0L ? Long.MAX_VALUE : initialTokensScaled;
            this.lastRefillNanos = nowNanos;
        }

        private void refill(long nowNanos, long refillRate, long capacityScaled)
        {
            if (nowNanos <= lastRefillNanos || refillRate <= 0L)
            {
                return;
            }
            long elapsedNanos = nowNanos - lastRefillNanos;
            lastRefillNanos = nowNanos;
            long accruedScaled = mulSaturating(elapsedNanos, refillRate);
            long sum = addSaturating(tokensScaled, accruedScaled);
            long ceiling = Math.max(tokensScaled, capacityScaled);
            tokensScaled = Math.min(sum, ceiling);
        }

        private long availableTokens()
        {
            return tokensScaled / NANOS_PER_SECOND;
        }
    }
}
