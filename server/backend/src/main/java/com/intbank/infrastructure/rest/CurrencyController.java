package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.CurrencyService;
import com.intbank.service.ExchangeRateCacheService;
import com.intbank.service.NotificationService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
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
    private final AccountJpaRepository accountRepo;
    private final AuditLogService auditLogService;
    private final NotificationService notificationService;

    public CurrencyController(CurrencyService currencyService,
                              ExchangeRateCacheService rateCache,
                              AccountJpaRepository accountRepo,
                              AuditLogService auditLogService,
                              NotificationService notificationService)
    {
        this.currencyService = currencyService;
        this.rateCache = rateCache;
        this.accountRepo = accountRepo;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
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
                "timestamp", System.currentTimeMillis()
        ));
    }

    @PostMapping("/convert")
    public ResponseEntity<Map<String, Object>> convert(@RequestBody Map<String, Object> body)
    {
        String from = (String) body.getOrDefault("from", "RON");
        String to = (String) body.getOrDefault("to", "EUR");
        Number amountNum = (Number) body.getOrDefault("amount", 1);
        double amount = amountNum.doubleValue();

        try
        {
            double result = currencyService.convertCurrency(amount, from, to);
            double rate = amount > 0 ? result / amount : 1.0;
            return ResponseEntity.ok(Map.of(
                    "from", from,
                    "to", to,
                    "amount", amount,
                    "result", result,
                    "rate", rate
            ));
        }
        catch (Exception e)
        {
            double fallbackRate = getFallbackRate(from, to);
            double result = Math.round(amount * fallbackRate * 100.0) / 100.0;
            return ResponseEntity.ok(Map.of(
                    "from", from,
                    "to", to,
                    "amount", amount,
                    "result", result,
                    "rate", fallbackRate
            ));
        }
    }

    @PostMapping("/users/{userId}/exchange/internal")
    @Transactional
    public ResponseEntity<Map<String, Object>> executeInternalExchange(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, Object> body)
    {
        Number fromAccountIdNum = (Number) body.get("fromAccountId");
        Number toAccountIdNum = (Number) body.get("toAccountId");
        Number amountNum = (Number) body.get("amount");

        if (fromAccountIdNum == null || toAccountIdNum == null || amountNum == null)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Parametri lipsa"));
        }

        Long fromAccountId = fromAccountIdNum.longValue();
        Long toAccountId = toAccountIdNum.longValue();
        BigDecimal sourceAmount = BigDecimal.valueOf(amountNum.doubleValue()).setScale(2, RoundingMode.HALF_EVEN);

        if (sourceAmount.compareTo(BigDecimal.ZERO) <= 0)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Suma trebuie sa fie pozitiva"));
        }

        var fromOpt = accountRepo.findById(fromAccountId).filter(a -> a.getUserId() != null && a.getUserId().equals(userId));
        var toOpt = accountRepo.findById(toAccountId).filter(a -> a.getUserId() != null && a.getUserId().equals(userId));

        if (fromOpt.isEmpty() || toOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Unul sau ambele conturi nu au fost gasite"));
        }

        AccountJpaEntity fromAccount = fromOpt.get();
        AccountJpaEntity toAccount = toOpt.get();

        if (fromAccount.getSold().compareTo(sourceAmount) < 0)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Fonduri insuficiente în contul sursa"));
        }

        double rate = 1.0;
        try
        {
            double converted = currencyService.convertCurrency(sourceAmount.doubleValue(), fromAccount.getMoneda(), toAccount.getMoneda());
            rate = converted / sourceAmount.doubleValue();
        }
        catch (Exception e)
        {
            rate = getFallbackRate(fromAccount.getMoneda(), toAccount.getMoneda());
        }

        BigDecimal destinationAmount = sourceAmount.multiply(BigDecimal.valueOf(rate)).setScale(2, RoundingMode.HALF_EVEN);

        fromAccount.setSold(fromAccount.getSold().subtract(sourceAmount));
        toAccount.setSold(toAccount.getSold().add(destinationAmount));

        accountRepo.save(fromAccount);
        accountRepo.save(toAccount);

        auditLogService.log(userId, "INTERNAL_FX_EXCHANGE",
                "Exchanged " + sourceAmount + " " + fromAccount.getMoneda() + " -> " + destinationAmount + " " + toAccount.getMoneda() + " (Rate: " + rate + ")", "127.0.0.1");

        notificationService.notify(userId, "Schimb valutar finalizat",
                "Ai schimbat " + sourceAmount + " " + fromAccount.getMoneda() + " în " + destinationAmount + " " + toAccount.getMoneda(), "TRANSFER_SENT");

        return ResponseEntity.ok(Map.of(
                "success", true,
                "sourceAmount", sourceAmount,
                "sourceCurrency", fromAccount.getMoneda(),
                "destinationAmount", destinationAmount,
                "destinationCurrency", toAccount.getMoneda(),
                "rate", rate,
                "fromAccountSold", fromAccount.getSold(),
                "toAccountSold", toAccount.getSold()
        ));
    }

    private double getFallbackRate(String from, String to)
    {
        if (from.equals(to)) return 1.0;
        if ("RON".equals(from) && "EUR".equals(to)) return 0.201;
        if ("RON".equals(from) && "USD".equals(to)) return 0.218;
        if ("RON".equals(from) && "GBP".equals(to)) return 0.171;
        if ("EUR".equals(from) && "RON".equals(to)) return 4.97;
        if ("USD".equals(from) && "RON".equals(to)) return 4.58;
        if ("GBP".equals(from) && "RON".equals(to)) return 5.85;
        if ("EUR".equals(from) && "USD".equals(to)) return 1.08;
        if ("USD".equals(from) && "EUR".equals(to)) return 0.92;
        return 1.0;
    }
}
