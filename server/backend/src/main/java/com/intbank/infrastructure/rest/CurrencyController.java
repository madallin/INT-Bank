package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.service.AuditLogService;
import com.intbank.service.CurrencyExchangeService;
import com.intbank.service.CurrencyService;
import com.intbank.service.ExchangeRateCacheService;
import com.intbank.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/currency/api/v1")
public class CurrencyController
{

    private final CurrencyService currencyService;
    private final ExchangeRateCacheService rateCache;
    private final AuditLogService auditLogService;
    private final NotificationService notificationService;
    private final CurrencyExchangeService exchangeService;

    public CurrencyController(CurrencyService currencyService,
                              ExchangeRateCacheService rateCache,
                              AuditLogService auditLogService,
                              NotificationService notificationService,
                              CurrencyExchangeService exchangeService)
    {
        this.currencyService = currencyService;
        this.rateCache = rateCache;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
        this.exchangeService = exchangeService;
    }

    @GetMapping("/exchange-rates")
    public ResponseEntity<Map<String, Object>> getExchangeRates(
            @RequestParam(value = "base", defaultValue = "RON") String base)
    {
        Map<String, Double> rates = new LinkedHashMap<>();
        rates.put("RON", 1.0);
        rates.put("EUR", 0.201);
        rates.put("USD", 0.218);
        rates.put("GBP", 0.171);

        for (String target : List.of("EUR", "USD", "GBP"))
        {
            Double cached = rateCache.getRate(base, target);
            if (cached != null)
            {
                rates.put(target, cached);
            }
        }

        return ResponseEntity.ok(Map.of(
                "base", base,
                "rates", rates,
                // The bank charges no exchange fee; the app shows this instead of assuming one.
                "commission_percent", 0,
                "timestamp", System.currentTimeMillis()
        ));
    }

    @PostMapping("/convert")
    public ResponseEntity<Map<String, Object>> convert(@RequestBody Map<String, Object> body)
    {
        String from = (String) body.getOrDefault("from", "RON");
        String to = (String) body.getOrDefault("to", "EUR");
        BigDecimal amount = parseAmount(body.getOrDefault("amount", 1));
        if (amount == null)
        {
            return ResponseEntity.badRequest().body(Map.of("code", BusinessRuleException.INVALID_AMOUNT, "error", "Suma invalida"));
        }

        BigDecimal rate = currencyService.getRate(from, to);
        BigDecimal result = amount.multiply(rate).setScale(2, RoundingMode.DOWN);
        return ResponseEntity.ok(Map.of(
                "from", from,
                "to", to,
                "amount", amount,
                "result", result,
                "rate", rate
        ));
    }

    /**
     * Prices an exchange between two of the caller's own accounts (no money moves). The quote is
     * honoured for {@link CurrencyExchangeService#QUOTE_TTL}. {@code UserScopeAuthorizationFilter}
     * rejects any {userId} other than the token's.
     */
    @PostMapping("/users/{userId}/exchange/quote")
    public ResponseEntity<Map<String, Object>> quoteExchange(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, Object> body)
    {
        Number fromAccountIdNum = (Number) body.get("fromAccountId");
        Number toAccountIdNum = (Number) body.get("toAccountId");
        BigDecimal amount = parseAmount(body.get("amount"));
        if (fromAccountIdNum == null || toAccountIdNum == null || amount == null)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Parametri lipsa"));
        }
        var quote = exchangeService.quote(userId, fromAccountIdNum.longValue(), toAccountIdNum.longValue(), amount);
        return ResponseEntity.ok(Map.of(
                "quoteId", quote.quoteId(),
                "sourceAmount", quote.sourceAmount(),
                "sourceCurrency", quote.sourceCurrency(),
                "destinationAmount", quote.destinationAmount(),
                "destinationCurrency", quote.destinationCurrency(),
                "rate", quote.rate(),
                "expiresAt", quote.expiresAt().toString()
        ));
    }

    /** Executes a quote. Safe to retry: the same quote never moves money twice. */
    @PostMapping("/users/{userId}/exchange/internal")
    public ResponseEntity<Map<String, Object>> executeInternalExchange(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, Object> body)
    {
        var execution = exchangeService.execute(userId, body.get("quoteId") instanceof String id ? id : null);
        var result = execution.result();

        if (!execution.replayed())
        {
            auditLogService.log(userId, "INTERNAL_FX_EXCHANGE",
                    "Exchanged " + result.sourceAmount() + " " + result.sourceCurrency() + " -> " + result.destinationAmount()
                            + " " + result.destinationCurrency() + " (Rate: " + result.rate() + ", id " + result.exchangeId() + ")", null);
            notificationService.notify(userId, "Schimb valutar finalizat",
                    "Ai schimbat " + result.sourceAmount() + " " + result.sourceCurrency() + " în " + result.destinationAmount()
                            + " " + result.destinationCurrency(), "TRANSFER_SENT");
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "exchangeId", result.exchangeId(),
                "sourceAmount", result.sourceAmount(),
                "sourceCurrency", result.sourceCurrency(),
                "destinationAmount", result.destinationAmount(),
                "destinationCurrency", result.destinationCurrency(),
                "rate", result.rate(),
                "fromAccountSold", result.fromAccountBalance(),
                "toAccountSold", result.toAccountBalance()
        ));
    }

    /** Parses a JSON number or numeric string without going through binary floating point. */
    private static BigDecimal parseAmount(Object raw)
    {
        if (!(raw instanceof Number) && !(raw instanceof String))
        {
            return null;
        }
        try
        {
            return new BigDecimal(raw.toString().trim());
        }
        catch (NumberFormatException e)
        {
            return null;
        }
    }
}
