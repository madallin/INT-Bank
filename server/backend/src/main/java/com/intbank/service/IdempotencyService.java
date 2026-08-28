package com.intbank.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.infrastructure.persistence.entity.IdempotencyRecordJpaEntity;
import com.intbank.infrastructure.persistence.repository.IdempotencyJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;

@Service
public class IdempotencyService
{

    private static final Logger log = LoggerFactory.getLogger(IdempotencyService.class);
    private static final Duration LOCK_TTL = Duration.ofSeconds(120);

    public enum Outcome
    {
        PROCEED, DUPLICATE_COMPLETED, DUPLICATE_IN_PROGRESS
    }

    public record Decision(Outcome outcome, String cachedResponsePayload)
    {
    }

    private final IdempotencyJpaRepository idempotencyRepo;
    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    public IdempotencyService(IdempotencyJpaRepository idempotencyRepo,
                              RedisTemplate<String, String> redisTemplate,
                              ObjectMapper objectMapper)
    {
        this.idempotencyRepo = idempotencyRepo;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    public Decision beginOrGet(String key, Long userId, String requestHash)
    {
        String lockKey = "idem:lock:" + key;
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(lockKey, "1", LOCK_TTL);
        if (Boolean.FALSE.equals(acquired))
        {
            log.debug("Idempotency-Key {} already locked by an in-flight request", key);
            return new Decision(Outcome.DUPLICATE_IN_PROGRESS, null);
        }

        try
        {
            var existing = idempotencyRepo.findByIdempotencyKey(key);
            if (existing.isEmpty())
            {
                IdempotencyRecordJpaEntity rec = new IdempotencyRecordJpaEntity();
                rec.setIdempotencyKey(key);
                rec.setUserId(userId);
                rec.setRequestHash(requestHash);
                rec.setStatus("IN_PROGRESS");
                rec.setExpiresAt(Instant.now().plus(LOCK_TTL));
                idempotencyRepo.save(rec);
                return new Decision(Outcome.PROCEED, null);
            }

            IdempotencyRecordJpaEntity rec = existing.get();
            if (!rec.getRequestHash().equals(requestHash))
            {
                throw new IllegalStateException(
                        "Idempotency-Key " + key + " was reused with a different request payload");
            }

            return switch (rec.getStatus())
            {
                case "COMPLETED" ->
                {
                    redisTemplate.delete(lockKey);
                    yield new Decision(Outcome.DUPLICATE_COMPLETED, rec.getResponsePayload());
                }
                case "IN_PROGRESS" -> new Decision(Outcome.PROCEED, null);
                case "FAILED" ->
                {
                    rec.setStatus("IN_PROGRESS");
                    rec.setExpiresAt(Instant.now().plus(LOCK_TTL));
                    idempotencyRepo.save(rec);
                    yield new Decision(Outcome.PROCEED, null);
                }
                default -> new Decision(Outcome.PROCEED, null);
            };
        }
        finally
        {
            // Release the lock only for terminal-duplicate (COMPLETED) outcomes.
            // For PROCEED the lock is released in complete()/fail().
        }
    }

    public void complete(String key, Object responsePayload)
    {
        try
        {
            String json = objectMapper.writeValueAsString(responsePayload);
            idempotencyRepo.findByIdempotencyKey(key).ifPresent(rec ->
            {
                rec.setStatus("COMPLETED");
                rec.setResponsePayload(json);
                idempotencyRepo.save(rec);
            });
        }
        catch (Exception e)
        {
            log.error("Failed to persist idempotency completion for key {}", key, e);
        }
        finally
        {
            redisTemplate.delete("idem:lock:" + key);
        }
    }

    public void fail(String key, String failureReason)
    {
        try
        {
            idempotencyRepo.findByIdempotencyKey(key).ifPresent(rec ->
            {
                rec.setStatus("FAILED");
                rec.setResponsePayload(failureReason);
                idempotencyRepo.save(rec);
            });
        }
        finally
        {
            redisTemplate.delete("idem:lock:" + key);
        }
    }

    public static String hashRequest(BigDecimal amount, String currency, String fromIban, String toIban, String reason)
    {
        try
        {
            String canonical = (fromIban == null ? "" : fromIban) + "|"
                    + (toIban == null ? "" : toIban) + "|"
                    + (amount == null ? "" : amount.toPlainString()) + "|"
                    + (currency == null ? "" : currency) + "|"
                    + (reason == null ? "" : reason);
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(canonical.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash)
            {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Unable to hash request for idempotency", e);
        }
    }
}
