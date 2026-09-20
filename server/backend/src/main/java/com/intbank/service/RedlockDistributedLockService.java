package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Distributed Concurrency & Locking service implemented with Redis and Lettuce.
 * Provides mutual exclusion across horizontal application pods (e.g. Kubernetes pods)
 * using unique lock ownership tokens and atomic Lua script release to prevent race conditions.
 */
@Service
public class RedlockDistributedLockService
{

    private static final Logger log = LoggerFactory.getLogger(RedlockDistributedLockService.class);

    // Atomic Lua script to ensure a lock is only deleted if the value matches the owner's token
    private static final String UNLOCK_LUA =
            "if redis.call('get', KEYS[1]) == ARGV[1] then " +
            "    return redis.call('del', KEYS[1]) " +
            "else " +
            "    return 0 " +
            "end";

    private static final RedisScript<Long> RELEASE_LOCK_SCRIPT = new DefaultRedisScript<>(UNLOCK_LUA, Long.class);

    private final RedisTemplate<String, String> redisTemplate;
    private final ThreadLocal<Map<String, String>> threadLocks = ThreadLocal.withInitial(HashMap::new);
    private final ConcurrentHashMap<String, String> activeLocks = new ConcurrentHashMap<>();

    public RedlockDistributedLockService(RedisTemplate<String, String> redisTemplate)
    {
        this.redisTemplate = redisTemplate;
    }

    /**
     * Attempts to acquire a distributed lock on lockKey with a given timeout.
     *
     * @param lockKey the unique lock key (e.g. account:lock:&lt;accountId&gt;)
     * @param timeoutSeconds max wait time in seconds to acquire the lock; also serves as the lock lease TTL
     * @return true if the lock was acquired, false otherwise
     */
    public boolean acquireLock(String lockKey, long timeoutSeconds)
    {
        if (lockKey == null || lockKey.isBlank())
        {
            log.warn("Attempted to acquire lock with empty or null lockKey");
            return false;
        }

        long leaseSeconds = timeoutSeconds > 0 ? timeoutSeconds : 30;
        long waitMillis = timeoutSeconds > 0 ? timeoutSeconds * 1000L : 0;
        long deadline = System.currentTimeMillis() + waitMillis;
        String token = UUID.randomUUID().toString() + ":" + Thread.currentThread().threadId();

        try
        {
            do
            {
                Boolean acquired = redisTemplate.opsForValue().setIfAbsent(
                        lockKey,
                        token,
                        Duration.ofSeconds(leaseSeconds)
                );

                if (Boolean.TRUE.equals(acquired))
                {
                    threadLocks.get().put(lockKey, token);
                    activeLocks.put(lockKey, token);
                    log.debug("Acquired distributed lock [{}] with token [{}] for {}s lease", lockKey, token, leaseSeconds);
                    return true;
                }

                if (System.currentTimeMillis() >= deadline)
                {
                    break;
                }

                try
                {
                    long sleepTime = Math.min(100L, Math.max(10L, deadline - System.currentTimeMillis()));
                    Thread.sleep(sleepTime);
                }
                catch (InterruptedException ie)
                {
                    Thread.currentThread().interrupt();
                    log.warn("Interrupted while waiting for distributed lock [{}]", lockKey);
                    return false;
                }
            }
            while (System.currentTimeMillis() < deadline);

            log.warn("Failed to acquire distributed lock [{}] within {}s", lockKey, timeoutSeconds);
            return false;
        }
        catch (Exception e)
        {
            log.error("Error acquiring distributed lock for key {}: {}", lockKey, e.getMessage(), e);
            return false;
        }
    }

    /**
     * Releases a previously acquired distributed lock on lockKey.
     * Uses an atomic Lua script to release only if the caller owns the lock token.
     *
     * @param lockKey the unique lock key to release
     */
    public void releaseLock(String lockKey)
    {
        if (lockKey == null || lockKey.isBlank())
        {
            return;
        }

        try
        {
            String token = threadLocks.get().remove(lockKey);
            if (token == null)
            {
                token = activeLocks.remove(lockKey);
            }
            else
            {
                activeLocks.remove(lockKey);
            }

            if (token != null)
            {
                Long result = redisTemplate.execute(RELEASE_LOCK_SCRIPT, Collections.singletonList(lockKey), token);
                if (Long.valueOf(1L).equals(result))
                {
                    log.debug("Released distributed lock [{}] for token [{}]", lockKey, token);
                }
                else
                {
                    log.warn("Distributed lock [{}] was already expired or held by another owner", lockKey);
                }
            }
            else
            {
                // Fallback cleanup if token wasn't registered in current thread context
                Boolean deleted = redisTemplate.delete(lockKey);
                log.debug("Fallback direct delete of lock [{}] (deleted: {})", lockKey, deleted);
            }
        }
        catch (Exception e)
        {
            log.error("Error releasing distributed lock for key {}: {}", lockKey, e.getMessage(), e);
        }
    }
}
