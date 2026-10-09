package com.intbank.service;

import com.intbank.service.CurrencyExchangeService.ExchangeResult;
import com.intbank.service.CurrencyExchangeService.Quote;

import java.time.Duration;
import java.util.Optional;

/** Short-lived storage for exchange quotes and their outcome (Redis in production). */
public interface ExchangeQuoteStore
{
    void save(Quote quote, Duration ttl);

    Optional<Quote> find(String quoteId);

    /** Marks the quote as being executed; only the first caller gets {@code true}. */
    boolean claim(String quoteId);

    /** Undoes {@link #claim} after a failed execution, so the customer can try again. */
    void release(String quoteId);

    void saveResult(String quoteId, ExchangeResult result);

    Optional<ExchangeResult> result(String quoteId);
}
