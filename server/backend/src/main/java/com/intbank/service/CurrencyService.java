package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class CurrencyService
{

    private static final Logger log = LoggerFactory.getLogger(CurrencyService.class);
    private static final String FRANKFURTER_API = "https://api.frankfurter.dev/v2/latest";
    private final RestTemplate restTemplate = new RestTemplate();

    public double convertCurrency(double amount, String fromCurrency, String toCurrency)
    {
        if (fromCurrency.equals(toCurrency)) return amount;

        try {
            String url = FRANKFURTER_API + "?base=" + fromCurrency + "&symbols=" + toCurrency;
            var response = restTemplate.getForObject(url, java.util.Map.class);
            if (response == null) throw new RuntimeException("No response from currency API");

            @SuppressWarnings("unchecked")
            var rates = (java.util.Map<String, Double>) response.get("rates");
            if (rates == null || !rates.containsKey(toCurrency)) {
                throw new RuntimeException("No rate found for " + fromCurrency + " -> " + toCurrency);
            }
            return Math.round(amount * rates.get(toCurrency));
        } catch (Exception err) {
            log.error("Error converting currency", err);
            throw new RuntimeException("Currency conversion failed", err);
        }
    }
}