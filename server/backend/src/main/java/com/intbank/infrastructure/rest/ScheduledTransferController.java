package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.service.DynamicLinkingService;
import com.intbank.service.StrongCustomerAuthService;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import com.intbank.service.AuditLogService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/scheduled-transfers")
public class ScheduledTransferController
{

    private final ScheduledTransferJpaRepository scheduledRepo;
    private final AccountJpaRepository accountRepo;
    private final AuditLogService auditLogService;
    private final StrongCustomerAuthService strongCustomerAuth;

    private static final java.util.Set<String> FREQUENCIES = java.util.Set.of("ONCE", "WEEKLY", "MONTHLY");

    public ScheduledTransferController(ScheduledTransferJpaRepository scheduledRepo,
                                       AccountJpaRepository accountRepo,
                                       AuditLogService auditLogService,
                                       StrongCustomerAuthService strongCustomerAuth)
    {
        this.scheduledRepo = scheduledRepo;
        this.accountRepo = accountRepo;
        this.auditLogService = auditLogService;
        this.strongCustomerAuth = strongCustomerAuth;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getScheduledTransfers(@PathVariable("userId") Long userId)
    {
        List<ScheduledTransferJpaEntity> list = scheduledRepo.findByUserIdOrderByNextRunDateAsc(userId);
        return ResponseEntity.ok(Map.of("scheduledTransfers", list));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createScheduledTransfer(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, Object> body)
    {
        String toIban = body.get("toIban") instanceof String raw ? raw.replaceAll("\\s+", "").toUpperCase() : null;
        String beneficiaryName = (String) body.get("beneficiaryName");
        String reason = (String) body.get("reason");
        Object amountRaw = body.get("amount");
        String frequency = String.valueOf(body.getOrDefault("frequency", "MONTHLY")).toUpperCase();
        String nextRunDateStr = (String) body.get("nextRunDate");

        if (toIban == null || beneficiaryName == null || reason == null || amountRaw == null || nextRunDateStr == null)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Parametri obligatorii lipsa"));
        }
        if (!FREQUENCIES.contains(frequency))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Frecventa trebuie sa fie ONCE, WEEKLY sau MONTHLY"));
        }
        BigDecimal amount;
        try
        {
            amount = new BigDecimal(amountRaw.toString());
        }
        catch (NumberFormatException e)
        {
            amount = null;
        }
        if (amount == null || amount.signum() <= 0 || amount.scale() > 2)
        {
            return ResponseEntity.badRequest().body(new BusinessRuleException(BusinessRuleException.INVALID_AMOUNT,
                    "Suma trebuie să fie pozitivă, cu cel mult două zecimale").toBody());
        }

        List<AccountJpaEntity> accounts = accountRepo.findByUser_Id(userId).stream().filter(AccountJpaEntity::isCurrent).toList();
        if (accounts.isEmpty())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Utilizatorul nu are niciun cont"));
        }
        AccountJpaEntity account = accounts.get(0);
        if (body.get("fromIban") instanceof String fromIban && !fromIban.isBlank())
        {
            var selected = accounts.stream().filter(a -> fromIban.trim().equalsIgnoreCase(a.getIBAN())).findFirst();
            if (selected.isEmpty())
            {
                return ResponseEntity.badRequest().body(new BusinessRuleException(BusinessRuleException.ACCOUNT_NOT_OWNED,
                        "Contul sursă nu îți aparține").toBody());
            }
            account = selected.get();
        }

        // Reject now what could never be paid later: only INTBank accounts, same currency.
        var destination = accountRepo.findByIBAN(toIban);
        if (destination.isEmpty() || !destination.get().isCurrent())
        {
            return ResponseEntity.badRequest().body(new BusinessRuleException(BusinessRuleException.DESTINATION_NOT_FOUND,
                    "Nu există niciun cont INTBank cu IBAN-ul " + toIban + ".").toBody());
        }
        if (!destination.get().getMoneda().equals(account.getMoneda()))
        {
            return ResponseEntity.badRequest().body(new BusinessRuleException(BusinessRuleException.CURRENCY_MISMATCH,
                    "Contul destinatarului este în " + destination.get().getMoneda() + ", iar plata este în "
                            + account.getMoneda() + ".").toBody());
        }
        if (destination.get().getId().equals(account.getId()))
        {
            return ResponseEntity.badRequest().body(new BusinessRuleException(BusinessRuleException.SAME_ACCOUNT,
                    "Alege un cont diferit de cel sursă").toBody());
        }

        LocalDate nextRunDate = LocalDate.parse(nextRunDateStr);
        if (nextRunDate.isBefore(LocalDate.now()))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Data de executare nu poate fi în trecut"));
        }

        // The customer authorizes the standing order now; later runs reuse this consent.
        try
        {
            strongCustomerAuth.authorize(new DynamicLinkingService.Payment(userId, account.getIBAN(), toIban, amount, account.getMoneda()),
                    body.get("scaChallengeId") instanceof String id ? id : null,
                    body.get("scaPin") instanceof String pin ? pin : null);
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

        ScheduledTransferJpaEntity st = new ScheduledTransferJpaEntity();
        st.setUserId(userId);
        st.setFromAccountId(account.getId());
        st.setToIban(toIban);
        st.setBeneficiaryName(beneficiaryName.trim());
        st.setAmount(amount);
        st.setCurrency(account.getMoneda());
        st.setReason(reason);
        st.setFrequency(frequency);
        st.setNextRunDate(nextRunDate);
        st.setStatus("ACTIVE");

        scheduledRepo.save(st);
        auditLogService.log(userId, "SCHEDULED_TRANSFER_CREATED",
                "Created scheduled transfer of " + st.getAmount() + " " + st.getCurrency() + " (" + frequency + ")", "127.0.0.1");

        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("success", true, "scheduledTransfer", st));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> cancelScheduledTransfer(
            @PathVariable("userId") Long userId,
            @PathVariable("id") Long id)
    {
        var opt = scheduledRepo.findById(id).filter(st -> st.getUserId().equals(userId));
        if (opt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Plata programata inexistenta"));
        }
        ScheduledTransferJpaEntity st = opt.get();
        st.setStatus("CANCELLED");
        scheduledRepo.save(st);

        auditLogService.log(userId, "SCHEDULED_TRANSFER_CANCELLED", "Cancelled scheduled transfer ID " + id, "127.0.0.1");
        return ResponseEntity.ok(Map.of("success", true));
    }
}
