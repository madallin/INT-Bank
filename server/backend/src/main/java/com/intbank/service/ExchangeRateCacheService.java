package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class ExchangeRateCacheService
{

    private static final Logger log = LoggerFactory.getLogger(ExchangeRateCacheService.class);
    private final RedisTemplate<String, String> redisTemplate;

    public ExchangeRateCacheService(RedisTemplate<String, String> redisTemplate)
    {
        this.redisTemplate = redisTemplate;
    }

    public void cacheRate(String fromCurrency, String toCurrency, double rate)
    {
        String key = "fx:" + fromCurrency + ":" + toCurrency;
        redisTemplate.opsForValue().set(key, String.valueOf(rate), 1, TimeUnit.HOURS);
    }

    public Double getRate(String fromCurrency, String toCurrency)
    {
        String key = "fx:" + fromCurrency + ":" + toCurrency;
        String value = redisTemplate.opsForValue().get(key);
        return value != null ? Double.parseDouble(value) : null;
    }
}