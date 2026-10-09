package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.service.AuditLogService;
import com.intbank.service.VaultService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Map;

/**
 * Savings vaults of one customer. {@code UserScopeAuthorizationFilter} only lets the customer
 * named in the path (or an admin) through; the service checks every account and vault id
 * belongs to them. Rule violations are answered by {@code GlobalExceptionHandler} with a code.
 */
@RestController
@RequestMapping("/users/{userId}/vaults")
public class VaultController
{

    private final VaultService vaults;
    private final AuditLogService auditLogService;

    public VaultController(VaultService vaults, AuditLogService auditLogService)
    {
        this.vaults = vaults;
        this.auditLogService = auditLogService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> list(@PathVariable("userId") Long userId)
    {
        return ResponseEntity.ok(Map.of("vaults", vaults.list(userId).stream().map(VaultService.VaultView::toMap).toList()));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@PathVariable("userId") Long userId, @RequestBody Map<String, Object> body)
    {
        var vault = vaults.create(userId,
                body.get("name") instanceof String name ? name : null,
                decimal(body.get("targetAmount")),
                date(body.get("targetDate")),
                body.get("lockType") instanceof String lock ? lock : null,
                id(body.get("sourceAccountId")));
        auditLogService.log(userId, "VAULT_CREATED", "Vault " + vault.id() + " (" + vault.currency() + ")", null);
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("success", true, "vault", vault.toMap()));
    }

    @PostMapping("/{vaultId}/deposit")
    public ResponseEntity<Map<String, Object>> deposit(@PathVariable("userId") Long userId,
                                                       @PathVariable("vaultId") Long vaultId,
                                                       @RequestBody Map<String, Object> body)
    {
        BigDecimal amount = decimal(body.get("amount"));
        var vault = vaults.deposit(userId, vaultId, id(body.get("accountId")), amount);
        auditLogService.log(userId, "VAULT_DEPOSIT", "Vault " + vaultId + " +" + amount + " " + vault.currency(), null);
        return ResponseEntity.ok(Map.of("success", true, "vault", vault.toMap()));
    }

    @PostMapping("/{vaultId}/withdraw")
    public ResponseEntity<Map<String, Object>> withdraw(@PathVariable("userId") Long userId,
                                                        @PathVariable("vaultId") Long vaultId,
                                                        @RequestBody Map<String, Object> body)
    {
        BigDecimal amount = decimal(body.get("amount"));
        var vault = vaults.withdraw(userId, vaultId, id(body.get("accountId")), amount);
        auditLogService.log(userId, "VAULT_WITHDRAWAL", "Vault " + vaultId + " -" + amount + " " + vault.currency(), null);
        return ResponseEntity.ok(Map.of("success", true, "vault", vault.toMap()));
    }

    /** Pays the remaining balance to {@code accountId} and closes the vault. */
    @PostMapping("/{vaultId}/close")
    public ResponseEntity<Map<String, Object>> close(@PathVariable("userId") Long userId,
                                                     @PathVariable("vaultId") Long vaultId,
                                                     @RequestBody Map<String, Object> body)
    {
        vaults.close(userId, vaultId, id(body.get("accountId")));
        auditLogService.log(userId, "VAULT_CLOSED", "Vault " + vaultId, null);
        return ResponseEntity.ok(Map.of("success", true));
    }

    private static BigDecimal decimal(Object raw)
    {
        if (raw instanceof Number || raw instanceof String)
        {
            try
            {
                return new BigDecimal(raw.toString().trim());
            }
            catch (NumberFormatException ignored)
            {
                // reported below
            }
        }
        throw new BusinessRuleException(BusinessRuleException.INVALID_AMOUNT, "Suma nu este validă.");
    }

    private static Long id(Object raw)
    {
        return raw instanceof Number number ? number.longValue() : null;
    }

    private static LocalDate date(Object raw)
    {
        if (!(raw instanceof String text) || text.isBlank()) return null;
        try
        {
            return LocalDate.parse(text);
        }
        catch (DateTimeParseException e)
        {
            throw new BusinessRuleException(BusinessRuleException.VAULT_INVALID, "Data țintă nu este validă.");
        }
    }
}
