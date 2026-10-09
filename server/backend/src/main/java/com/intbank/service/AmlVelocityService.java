package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Duration;

@Service
public class AmlVelocityService
{

    private static final Logger log = LoggerFactory.getLogger(AmlVelocityService.class);
    private static final int MAX_TRANSFERS_5_MIN = 5;
    /** Daily outgoing limit per currency (rolling 24 hours). Unknown currencies get the strictest. */
    static final java.util.Map<String, BigDecimal> DAILY_LIMITS = java.util.Map.of(
            "RON", new BigDecimal("50000.00"),
            "EUR", new BigDecimal("10000.00"),
            "USD", new BigDecimal("11000.00"),
            "GBP", new BigDecimal("8500.00"));
    private static final BigDecimal STRICTEST_DAILY_LIMIT = new BigDecimal("8500.00");
    private static final BigDecimal HIGH_VALUE_THRESHOLD = BigDecimal.valueOf(1000.00);

    private final RedisTemplate<String, String> redisTemplate;

    public AmlVelocityService(RedisTemplate<String, String> redisTemplate)
    {
        this.redisTemplate = redisTemplate;
    }

    public enum RiskAssessment
    {
        PASS,
        VELOCITY_LIMIT_EXCEEDED,
        DAILY_LIMIT_EXCEEDED,
        REQUIRES_STEP_UP_AUTH
    }

    public record AmlResult(RiskAssessment assessment, boolean requiresStepUp, String message)
    {
    }

    public AmlResult evaluateTransfer(Long userId, BigDecimal amount, String currency)
    {
        if (userId == null)
        {
            return new AmlResult(RiskAssessment.PASS, false, "Assessment passed");
        }

        // 1. Velocity check: max 5 transfers in 5 minutes
        String velocityKey = "aml:vel:" + userId;
        Long currentCount = redisTemplate.opsForValue().increment(velocityKey);
        if (currentCount != null && currentCount == 1)
        {
            redisTemplate.expire(velocityKey, Duration.ofMinutes(5));
        }
        if (currentCount != null && currentCount > MAX_TRANSFERS_5_MIN)
        {
            log.warn("AML Alert: User {} exceeded velocity limit ({} transfers in 5 min)", userId, currentCount);
            return new AmlResult(RiskAssessment.VELOCITY_LIMIT_EXCEEDED, false,
                    "Limita de viteza depasita. Maxim 5 transferuri la fiecare 5 minute.");
        }

        // 2. Daily limit per currency. INCRBY is atomic, so parallel transfers cannot both slip
        //    under the limit (the old read-then-write could); an over-limit attempt is rolled back.
        BigDecimal dailyLimit = DAILY_LIMITS.getOrDefault(currency, STRICTEST_DAILY_LIMIT);
        String dailyKey = "aml:daily:" + userId + ":" + currency;
        long cents = amount.movePointRight(2).setScale(0, java.math.RoundingMode.UP).longValueExact();
        Long totalCents = redisTemplate.opsForValue().increment(dailyKey, cents);
        Long ttl = redisTemplate.getExpire(dailyKey);
        if (ttl != null && ttl < 0)
        {
            redisTemplate.expire(dailyKey, Duration.ofHours(24));
        }
        if (totalCents != null && BigDecimal.valueOf(totalCents, 2).compareTo(dailyLimit) > 0)
        {
            redisTemplate.opsForValue().decrement(dailyKey, cents);
            log.warn("AML Alert: User {} exceeded daily {} limit ({} > {})", userId, currency, BigDecimal.valueOf(totalCents, 2), dailyLimit);
            return new AmlResult(RiskAssessment.DAILY_LIMIT_EXCEEDED, false,
                    "Limita zilnica de " + dailyLimit.toPlainString() + " " + currency + " a fost depasita.");
        }

        // 3. Step-up SCA dynamic linking requirement for high-value transactions
        boolean requiresStepUp = amount.compareTo(HIGH_VALUE_THRESHOLD) > 0;
        if (requiresStepUp)
        {
            log.info("PSD2 SCA: Transfer of {} {} requires Dynamic Linking step-up challenge", amount, currency);
            return new AmlResult(RiskAssessment.REQUIRES_STEP_UP_AUTH, true, "Tranzactia necesita autentificare securizata (SCA).");
        }

        return new AmlResult(RiskAssessment.PASS, false, "Approved");
    }
}
