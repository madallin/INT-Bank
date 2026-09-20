package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.NotificationService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/users/{userId}/accounts")
public class AccountController
{

    private final AccountJpaRepository accountRepo;
    private final UserJpaRepository userRepo;
    private final AuditLogService auditLogService;
    private final NotificationService notificationService;

    public AccountController(AccountJpaRepository accountRepo,
                             UserJpaRepository userRepo,
                             AuditLogService auditLogService,
                             NotificationService notificationService)
    {
        this.accountRepo = accountRepo;
        this.userRepo = userRepo;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getAccounts(@PathVariable("userId") Long userId)
    {
        List<AccountJpaEntity> accounts = accountRepo.findByUser_Id(userId);
        var mapped = accounts.stream().map(this::toMap).toList();
        return ResponseEntity.ok(Map.of("accounts", mapped));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createAccount(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, String> body)
    {
        String currency = body.getOrDefault("currency", "EUR").toUpperCase();
        if (!List.of("EUR", "USD", "GBP", "RON").contains(currency))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Moneda nesuportata. Monede permise: EUR, USD, GBP, RON"));
        }

        var userOpt = userRepo.findById(userId);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent"));
        }
        UserJpaEntity user = userOpt.get();

        String suffix = UUID.randomUUID().toString().replaceAll("-", "").substring(0, 8).toUpperCase();
        String generatedIban = "RO49INTB" + String.format("%04d", userId) + currency + suffix;

        AccountJpaEntity account = new AccountJpaEntity();
        account.setUser(user);
        account.setIBAN(generatedIban);
        account.setMoneda(currency);
        account.setSold(BigDecimal.ZERO);
        account.setCreatedAt(Instant.now());

        AccountJpaEntity saved = accountRepo.save(account);

        auditLogService.log(userId, "SUB_ACCOUNT_OPENED", "Opened " + currency + " account: " + generatedIban, "127.0.0.1");
        notificationService.notify(userId, "Cont nou în " + currency + " deschis",
                "Noul tau cont curent în " + currency + " (" + generatedIban + ") este gata de utilizare.", "SYSTEM");

        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "success", true,
                "account", toMap(saved)
        ));
    }

    @GetMapping("/{accountId}")
    public ResponseEntity<Map<String, Object>> getAccount(
            @PathVariable("userId") Long userId,
            @PathVariable("accountId") Long accountId)
    {
        return accountRepo.findById(accountId)
                .filter(a -> a.getUserId() != null && a.getUserId().equals(userId))
                .map(a -> ResponseEntity.ok(Map.<String, Object>of("account", toMap(a))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Cont inexistent")));
    }

    private Map<String, Object> toMap(AccountJpaEntity a)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", a.getId());
        map.put("userId", a.getUserId());
        map.put("iban", a.getIBAN());
        map.put("IBAN", a.getIBAN());
        map.put("moneda", a.getMoneda());
        map.put("sold", a.getSold());
        map.put("createdAt", a.getCreatedAt() != null ? a.getCreatedAt().toString() : null);
        return map;
    }
}
