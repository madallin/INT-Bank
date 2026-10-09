package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.service.DynamicLinkingService;
import com.intbank.service.StrongCustomerAuthService;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
public class TransactionController
{

    private static final Logger log = LoggerFactory.getLogger(TransactionController.class);

    private final TransferUseCase transferUseCase;
    private final AccountJpaRepository accountRepo;
    private final TransferJpaRepository transferRepo;
    private final com.intbank.service.OutboxProcessorService outboxProcessorService;
    private final StrongCustomerAuthService strongCustomerAuth;

    @org.springframework.beans.factory.annotation.Autowired
    public TransactionController(TransferUseCase transferUseCase,
                                 AccountJpaRepository accountRepo,
                                 TransferJpaRepository transferRepo,
                                 StrongCustomerAuthService strongCustomerAuth,
                                 @org.springframework.beans.factory.annotation.Autowired(required = false) com.intbank.service.OutboxProcessorService outboxProcessorService,
                                 @org.springframework.beans.factory.annotation.Autowired(required = false) com.intbank.infrastructure.security.SecurityGuard securityGuard)
    {
        this.transferUseCase = transferUseCase;
        this.accountRepo = accountRepo;
        this.transferRepo = transferRepo;
        this.strongCustomerAuth = strongCustomerAuth;
        this.outboxProcessorService = outboxProcessorService;
        this.securityGuard = securityGuard;
    }

    private final com.intbank.infrastructure.security.SecurityGuard securityGuard;

    @GetMapping("/users/{userId}/accounts/{accountId}/transactions")
    public ResponseEntity<Map<String, Object>> getTransactions(
            @PathVariable("userId") Long userId,
            @PathVariable("accountId") Long accountId)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
        var accountOpt = accountRepo.findById(accountId);
        if (accountOpt.isEmpty() || !accountOpt.get().getUserId().equals(userId))
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Cont inexistent"));
        }

        AccountJpaEntity account = accountOpt.get();
        List<TransferJpaEntity> allTransfers = transferRepo.findByFromAccount_IdOrToAccount_IdOrderByInitiatedAtDesc(accountId, accountId);

        List<Map<String, Object>> list = allTransfers.stream()
                .filter(t -> (t.getFromAccount() != null && t.getFromAccount().getId().equals(accountId))
                        || (t.getToAccount() != null && t.getToAccount().getId().equals(accountId)))
                .sorted((a, b) -> b.getInitiatedAt().compareTo(a.getInitiatedAt()))
                .map(t -> {
                    boolean isDebit = t.getFromAccount() != null && t.getFromAccount().getId().equals(accountId);
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("id", t.getId());
                    map.put("trackingId", t.getId());
                    map.put("amount", t.getAmount());
                    map.put("currency", t.getCurrency());
                    map.put("type", isDebit ? "DEBIT" : "CREDIT");
                    map.put("reason", t.getReason());
                    map.put("description", t.getReason());
                    map.put("status", t.getStatus());
                    map.put("date", t.getInitiatedAt().toString());
                    map.put("fromIban", t.getFromAccount() != null ? t.getFromAccount().getIBAN() : "");
                    map.put("toIban", t.getToAccount() != null ? t.getToAccount().getIBAN() : "");
                    map.put("category", category(t, isDebit));
                    return map;
                })
                .toList();

        return ResponseEntity.ok(Map.of("transactions", list));
    }

    /**
     * What the app shows as the transaction's icon: a move between the customer's own accounts,
     * money received, or the spending category of a payment.
     */
    static String category(TransferJpaEntity t, boolean isDebit)
    {
        Long fromUser = t.getFromAccount() != null ? t.getFromAccount().getUserId() : null;
        Long toUser = t.getToAccount() != null ? t.getToAccount().getUserId() : null;
        if (fromUser != null && fromUser.equals(toUser)) return "OWN_ACCOUNTS";
        if (!isDebit) return "INCOMING";
        return com.intbank.service.AnalyticsService.categorize(t.getReason(), null);
    }

    @PostMapping("/users/{userId}/transfer")
    public ResponseEntity<Map<String, Object>> userTransfer(
            @PathVariable("userId") Long userId,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKeyHeader,
            @RequestBody Map<String, Object> body)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
        String rawToIban = (String) body.get("iban");
        String toIban = rawToIban == null ? null : rawToIban.replaceAll("\\s+", "").toUpperCase();
        String beneficiaryName = (String) body.get("beneficiaryName");
        String reason = (String) body.get("reason");
        Number amountNum = (Number) body.get("amount");

        if (toIban == null || amountNum == null || reason == null)
        {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Parametri lipsa"));
        }

        List<AccountJpaEntity> accounts = accountRepo.findByUser_Id(userId).stream().filter(AccountJpaEntity::isCurrent).toList();
        if (accounts.isEmpty())
        {
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", "Utilizatorul nu are niciun cont"));
        }

        AccountJpaEntity sourceAccount = accounts.get(0);
        String fromIban = (String) body.get("fromIban");
        if (fromIban != null && !fromIban.isBlank())
        {
            var selected = accounts.stream()
                    .filter(a -> fromIban.trim().equalsIgnoreCase(a.getIBAN()))
                    .findFirst();
            if (selected.isEmpty())
            {
                // Never fall back to another account: it may hold a different currency.
                return ResponseEntity.badRequest().body(Map.of("success", false,
                        "code", BusinessRuleException.ACCOUNT_NOT_OWNED,
                        "error", "Contul sursă nu îți aparține"));
            }
            sourceAccount = selected.get();
        }

        BigDecimal amount = new BigDecimal(amountNum.toString());

        // Large payments need the PIN again, bound to exactly these details.
        try
        {
            strongCustomerAuth.authorize(
                    new DynamicLinkingService.Payment(userId, sourceAccount.getIBAN(), toIban, amount, sourceAccount.getMoneda()),
                    stringOrNull(body.get("scaChallengeId")), stringOrNull(body.get("scaPin")));
        }
        catch (StrongCustomerAuthService.ScaRequiredException required)
        {
            return ResponseEntity.status(HttpStatus.PRECONDITION_REQUIRED).body(required.toBody());
        }
        catch (BusinessRuleException rejected)
        {
            HttpStatus status = BusinessRuleException.SCA_LOCKED.equals(rejected.code()) ? HttpStatus.LOCKED : HttpStatus.BAD_REQUEST;
            return ResponseEntity.status(status).body(rejected.toBody());
        }

        String key = (idempotencyKeyHeader != null && !idempotencyKeyHeader.isBlank())
                ? idempotencyKeyHeader.trim()
                : "tx-usr-" + userId + "-" + UUID.randomUUID().toString().substring(0, 12);

        try
        {
            var result = transferUseCase.initiate(new TransferUseCase.InitiateTransferRequest(
                    sourceAccount.getIBAN(),
                    toIban,
                    amount,
                    sourceAccount.getMoneda(),
                    reason,
                    beneficiaryName != null ? beneficiaryName : "Beneficiar",
                    sourceAccount.getUser().getNume() + " " + sourceAccount.getUser().getPrenume(),
                    key
            ));

            // Immediately drain outbox so local transfers settle and generate notifications without polling delay
            if (outboxProcessorService != null)
            {
                try
                {
                    outboxProcessorService.processNow();
                }
                catch (Exception ex)
                {
                    log.warn("Immediate outbox drain failed; scheduled worker will process: {}", ex.getMessage());
                }
            }

            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "trackingId", result.trackingId(),
                    "status", result.status().name(),
                    "message", result.message()
            ));
        }
        catch (Exception e)
        {
            log.error("Transfer error for user {}: {}", userId, e.getMessage());
            if (e instanceof BusinessRuleException rule)
            {
                return ResponseEntity.badRequest().body(rule.toBody());
            }
            return ResponseEntity.badRequest().body(Map.of("success", false, "error", e.getMessage()));
        }
    }

    private static String stringOrNull(Object value)
    {
        return value instanceof String text && !text.isBlank() ? text : null;
    }
}
