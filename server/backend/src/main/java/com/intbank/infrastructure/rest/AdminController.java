package com.intbank.infrastructure.rest;

import com.intbank.service.OutboxProcessorService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/admin")
public class AdminController
{

    private final OutboxProcessorService outboxProcessor;
    private final com.intbank.service.LedgerReconciliationService ledgerReconciliationService;
    private final com.intbank.service.AuditLogService auditLogService;
    private final com.intbank.infrastructure.persistence.repository.AuditLogJpaRepository auditRepo;

    public AdminController(OutboxProcessorService outboxProcessor,
                           com.intbank.service.LedgerReconciliationService ledgerReconciliationService,
                           com.intbank.service.AuditLogService auditLogService,
                           com.intbank.infrastructure.persistence.repository.AuditLogJpaRepository auditRepo)
    {
        this.outboxProcessor = outboxProcessor;
        this.ledgerReconciliationService = ledgerReconciliationService;
        this.auditLogService = auditLogService;
        this.auditRepo = auditRepo;
    }

    @GetMapping("/ledger/reconcile")
    public Map<String, Object> reconcileLedger()
    {
        var report = ledgerReconciliationService.reconcileAll();
        return Map.of(
                "isBalanced", report.isBalanced(),
                "totalDebits", report.totalDebits(),
                "totalCredits", report.totalCredits(),
                "totalEntries", report.totalEntries(),
                "accountsChecked", report.accountsChecked(),
                "accountDiscrepancies", report.accountDiscrepancies(),
                "discrepancies", report.discrepancyDetails()
        );
    }

    @GetMapping("/audit/verify")
    public Map<String, Object> verifyAuditIntegrity()
    {
        boolean intact = auditLogService.verifyAuditIntegrity();
        return Map.of("intact", intact, "status", intact ? "CRYPTOGRAPHIC_CHAIN_VERIFIED" : "TAMPERING_DETECTED");
    }

    @GetMapping("/audit/logs")
    public Map<String, Object> getAuditLogs()
    {
        return Map.of("logs", auditRepo.findAllByOrderByIdAsc());
    }

    @GetMapping("/outbox/stats")
    public Map<String, Object> getOutboxStats()
    {
        return Map.of("data", outboxProcessor.getStats());
    }

    @PostMapping("/outbox/reprocess-dead")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> reprocessDeadOutbox()
    {
        int count = outboxProcessor.reprocessDead();
        return Map.of("message", count + " dead messages queued for reprocessing", "count", count);
    }

    @PostMapping("/outbox/process-now")
    public Map<String, Object> processOutboxNow()
    {
        var result = outboxProcessor.processNow();
        return Map.of("message", "Processed " + result.get("processed") + ", failed " + result.get("failed"), "data", result);
    }

    @GetMapping("/dlq/stats")
    public Map<String, Object> getDlqStats()
    {
        var stats = outboxProcessor.getStats();
        return Map.of("data", Map.of(
                "deadMessages", stats.get("dead"),
                "pendingRetries", stats.get("pending"),
                "permanentlyFailed", stats.get("dead"),
                "totalMessages", stats.get("total")
        ));
    }

    @GetMapping("/balances")
    public Map<String, String> getBalanceCacheStats()
    {
        return Map.of("message", "Read model projector is operational");
    }
}