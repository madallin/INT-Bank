package com.intbank.service;

import com.intbank.core.domain.event.TransferCompletedEvent;
import com.intbank.core.domain.event.TransferFailedEvent;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class ReadModelProjectorService
{

    private static final Logger log = LoggerFactory.getLogger(ReadModelProjectorService.class);
    private final RedisTemplate<String, String> redisTemplate;

    public ReadModelProjectorService(RedisTemplate<String, String> redisTemplate)
    {
        this.redisTemplate = redisTemplate;
    }

    public void projectTransferInitiated(TransferInitiatedEvent event)
    {
        String key = "transfer:" + event.trackingId();
        redisTemplate.opsForHash().putAll(key, java.util.Map.of(
                "status", "PENDING",
                "amount", String.valueOf(event.amount()),
                "currency", event.currency()));
        redisTemplate.expire(key, 24, TimeUnit.HOURS);
    }

    public void projectTransferCompleted(TransferCompletedEvent event)
    {
        String key = "transfer:" + event.trackingId();
        redisTemplate.opsForHash().put(key, "status", "COMPLETED");
    }

    public void projectTransferFailed(TransferFailedEvent event)
    {
        String key = "transfer:" + event.trackingId();
        redisTemplate.opsForHash().putAll(key, java.util.Map.of(
                "status", "FAILED",
                "failureReason", event.failureReason()));
    }
}