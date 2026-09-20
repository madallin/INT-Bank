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
    private static final BigDecimal DAILY_LIMIT = BigDecimal.valueOf(50000.00);
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

        // 2. Daily Limit Check: max 50,000 RON / 24h
        String dailyKey = "aml:daily:" + userId;
        String currentDailyStr = redisTemplate.opsForValue().get(dailyKey);
        BigDecimal currentDaily = currentDailyStr != null ? new BigDecimal(currentDailyStr) : BigDecimal.ZERO;
        BigDecimal newDaily = currentDaily.add(amount);

        if (newDaily.compareTo(DAILY_LIMIT) > 0)
        {
            log.warn("AML Alert: User {} exceeded daily transfer limit ({} > {})", userId, newDaily, DAILY_LIMIT);
            return new AmlResult(RiskAssessment.DAILY_LIMIT_EXCEEDED, false,
                    "Limita zilnica de " + DAILY_LIMIT + " " + currency + " a fost depasita.");
        }

        // Record daily spending with 24h TTL
        redisTemplate.opsForValue().set(dailyKey, newDaily.toPlainString(), Duration.ofHours(24));

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
