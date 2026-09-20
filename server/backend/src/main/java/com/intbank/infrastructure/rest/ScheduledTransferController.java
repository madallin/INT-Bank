package com.intbank.infrastructure.rest;

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

    public ScheduledTransferController(ScheduledTransferJpaRepository scheduledRepo,
                                       AccountJpaRepository accountRepo,
                                       AuditLogService auditLogService)
    {
        this.scheduledRepo = scheduledRepo;
        this.accountRepo = accountRepo;
        this.auditLogService = auditLogService;
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
        String toIban = (String) body.get("toIban");
        String beneficiaryName = (String) body.get("beneficiaryName");
        String reason = (String) body.get("reason");
        Number amountNum = (Number) body.get("amount");
        String frequency = (String) body.getOrDefault("frequency", "MONTHLY");
        String nextRunDateStr = (String) body.get("nextRunDate");

        if (toIban == null || beneficiaryName == null || reason == null || amountNum == null || nextRunDateStr == null)
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Parametri obligatorii lipsa"));
        }

        List<AccountJpaEntity> accounts = accountRepo.findByUser_Id(userId);
        if (accounts.isEmpty())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Utilizatorul nu are niciun cont"));
        }
        AccountJpaEntity account = accounts.get(0);

        LocalDate nextRunDate = LocalDate.parse(nextRunDateStr);
        if (nextRunDate.isBefore(LocalDate.now()))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Data de executare nu poate fi în trecut"));
        }

        ScheduledTransferJpaEntity st = new ScheduledTransferJpaEntity();
        st.setUserId(userId);
        st.setFromAccountId(account.getId());
        st.setToIban(toIban.replaceAll("\\s+", "").toUpperCase());
        st.setBeneficiaryName(beneficiaryName.trim());
        st.setAmount(BigDecimal.valueOf(amountNum.doubleValue()));
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
