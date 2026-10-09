package com.intbank.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.service.CurrencyExchangeService.ExchangeResult;
import com.intbank.service.CurrencyExchangeService.Quote;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Optional;

@Component
public class RedisExchangeQuoteStore implements ExchangeQuoteStore
{

    /** Outcomes are kept a while longer than quotes, so a late retry still gets the original answer. */
    private static final Duration RESULT_TTL = Duration.ofMinutes(15);

    private final RedisTemplate<String, String> redis;
    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();

    public RedisExchangeQuoteStore(RedisTemplate<String, String> redis)
    {
        this.redis = redis;
    }

    @Override
    public void save(Quote quote, Duration ttl)
    {
        redis.opsForValue().set(key(quote.quoteId()), write(quote), ttl);
    }

    @Override
    public Optional<Quote> find(String quoteId)
    {
        return Optional.ofNullable(redis.opsForValue().get(key(quoteId))).map(v -> read(v, Quote.class));
    }

    @Override
    public boolean claim(String quoteId)
    {
        return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(key(quoteId) + ":claim", "1", RESULT_TTL));
    }

    @Override
    public void release(String quoteId)
    {
        redis.delete(key(quoteId) + ":claim");
    }

    @Override
    public void saveResult(String quoteId, ExchangeResult result)
    {
        redis.opsForValue().set(key(quoteId) + ":result", write(result), RESULT_TTL);
    }

    @Override
    public Optional<ExchangeResult> result(String quoteId)
    {
        return Optional.ofNullable(redis.opsForValue().get(key(quoteId) + ":result")).map(v -> read(v, ExchangeResult.class));
    }

    private static String key(String quoteId)
    {
        return "fx:quote:" + quoteId;
    }

    private String write(Object value)
    {
        try
        {
            return json.writeValueAsString(value);
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Cannot store exchange quote", e);
        }
    }

    private <T> T read(String value, Class<T> type)
    {
        try
        {
            return json.readValue(value, type);
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Cannot read exchange quote", e);
        }
    }
}
