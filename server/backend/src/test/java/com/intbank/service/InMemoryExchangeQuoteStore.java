package com.intbank.service;

import com.intbank.service.CurrencyExchangeService.ExchangeResult;
import com.intbank.service.CurrencyExchangeService.Quote;

import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/** Test double for the Redis-backed store, with the same first-claim-wins rule. */
public class InMemoryExchangeQuoteStore implements ExchangeQuoteStore
{
    final Map<String, Quote> quotes = new ConcurrentHashMap<>();
    final Map<String, ExchangeResult> results = new ConcurrentHashMap<>();
    final Set<String> claims = ConcurrentHashMap.newKeySet();

    @Override
    public void save(Quote quote, Duration ttl)
    {
        quotes.put(quote.quoteId(), quote);
    }

    @Override
    public Optional<Quote> find(String quoteId)
    {
        return Optional.ofNullable(quotes.get(quoteId));
    }

    @Override
    public boolean claim(String quoteId)
    {
        return claims.add(quoteId);
    }

    @Override
    public void release(String quoteId)
    {
        claims.remove(quoteId);
    }

    @Override
    public void saveResult(String quoteId, ExchangeResult result)
    {
        results.put(quoteId, result);
    }

    @Override
    public Optional<ExchangeResult> result(String quoteId)
    {
        return Optional.ofNullable(results.get(quoteId));
    }
}
