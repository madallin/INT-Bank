package com.intbank.service;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class TokenBlacklistService
{

    private final RedisTemplate<String, String> redisTemplate;

    public TokenBlacklistService(RedisTemplate<String, String> redisTemplate)
    {
        this.redisTemplate = redisTemplate;
    }

    public void blacklist(String token, long ttlSeconds)
    {
        redisTemplate.opsForValue().set("bl:" + token, "1", ttlSeconds, TimeUnit.SECONDS);
    }

    public boolean isBlacklisted(String token)
    {
        return Boolean.TRUE.equals(redisTemplate.hasKey("bl:" + token));
    }
}