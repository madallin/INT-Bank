package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Map;

@Service
public class CurrencyService
{

    private static final Logger log = LoggerFactory.getLogger(CurrencyService.class);
    private static final String FRANKFURTER_API = "https://api.frankfurter.dev/v2/latest";

    /**
     * Offline rates (units of target per one unit of source). Each direction is quoted
     * separately so a round trip loses the spread instead of creating money.
     */
    private static final Map<String, BigDecimal> STATIC_RATES = Map.of(
            "RON:EUR", new BigDecimal("0.201"),
            "RON:USD", new BigDecimal("0.218"),
            "RON:GBP", new BigDecimal("0.171"),
            "EUR:RON", new BigDecimal("4.97"),
            "USD:RON", new BigDecimal("4.58"),
            "GBP:RON", new BigDecimal("5.85"),
            "EUR:USD", new BigDecimal("1.08"),
            "USD:EUR", new BigDecimal("0.92")
    );

    private final RestTemplate restTemplate;

    public CurrencyService()
    {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        // Never let a slow FX provider hold a customer request (or a DB lock) open.
        factory.setConnectTimeout(2_000);
        factory.setReadTimeout(3_000);
        this.restTemplate = new RestTemplate(factory);
    }

    /**
     * Units of {@code toCurrency} for one unit of {@code fromCurrency}, unrounded.
     * Falls back to {@link #staticRate} when the provider is unavailable.
     */
    @io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker(name = "currencyService", fallbackMethod = "getRateFallback")
    public BigDecimal getRate(String fromCurrency, String toCurrency)
    {
        if (fromCurrency.equals(toCurrency)) return BigDecimal.ONE;

        String url = FRANKFURTER_API + "?base=" + fromCurrency + "&symbols=" + toCurrency;
        var response = restTemplate.getForObject(url, Map.class);
        if (response == null || !(response.get("rates") instanceof Map<?, ?> rates) || !(rates.get(toCurrency) instanceof Number rate))
        {
            throw new IllegalStateException("No rate found for " + fromCurrency + " -> " + toCurrency);
        }
        BigDecimal value = new BigDecimal(rate.toString());
        if (value.signum() <= 0)
        {
            throw new IllegalStateException("Non-positive rate for " + fromCurrency + " -> " + toCurrency);
        }
        return value;
    }

    public BigDecimal getRateFallback(String fromCurrency, String toCurrency, Throwable t)
    {
        log.warn("FX provider unavailable ({}); using static rate for {} -> {}", t.getMessage(), fromCurrency, toCurrency);
        return staticRate(fromCurrency, toCurrency);
    }

    /** Static rate for a supported pair; unknown pairs are rejected, never priced at 1:1. */
    public static BigDecimal staticRate(String fromCurrency, String toCurrency)
    {
        if (fromCurrency.equals(toCurrency)) return BigDecimal.ONE;
        BigDecimal rate = STATIC_RATES.get(fromCurrency + ":" + toCurrency);
        if (rate == null)
        {
            throw new BusinessRuleException(BusinessRuleException.UNSUPPORTED_CURRENCY_PAIR,
                    "Schimbul " + fromCurrency + " → " + toCurrency + " nu este disponibil.");
        }
        return rate;
    }
}
