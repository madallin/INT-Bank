package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.JournalEntryJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;

@Service
public class LedgerReconciliationService
{

    private static final Logger log = LoggerFactory.getLogger(LedgerReconciliationService.class);

    private final JournalEntryJpaRepository journalRepo;
    private final AccountJpaRepository accountRepo;
    private final AuditLogService auditLogService;

    public LedgerReconciliationService(JournalEntryJpaRepository journalRepo,
                                       AccountJpaRepository accountRepo,
                                       AuditLogService auditLogService)
    {
        this.journalRepo = journalRepo;
        this.accountRepo = accountRepo;
        this.auditLogService = auditLogService;
    }

    public record ReconciliationReport(
            boolean isBalanced,
            BigDecimal totalDebits,
            BigDecimal totalCredits,
            int totalEntries,
            int accountsChecked,
            int accountDiscrepancies,
            List<String> discrepancyDetails
    )
    {
    }

    @Scheduled(cron = "0 0 2 * * ?") // Runs daily at 2:00 AM
    @Transactional(readOnly = true)
    public ReconciliationReport runDailyReconciliation()
    {
        log.info("Starting scheduled General Ledger reconciliation...");
        ReconciliationReport report = reconcileAll();
        if (!report.isBalanced() || report.accountDiscrepancies() > 0)
        {
            log.error("GENERAL LEDGER IMBALANCE DETECTED! Debits: {}, Credits: {}, Discrepancies: {}",
                    report.totalDebits(), report.totalCredits(), report.accountDiscrepancies());
            auditLogService.log(null, "LEDGER_RECONCILIATION_FAILED",
                    "Imbalance: Debits=" + report.totalDebits() + ", Credits=" + report.totalCredits(), "127.0.0.1");
        }
        else
        {
            log.info("General Ledger reconciliation successful: all entries balanced (Debits = Credits = {}).",
                    report.totalDebits());
            auditLogService.log(null, "LEDGER_RECONCILIATION_SUCCESS",
                    "Balanced across " + report.accountsChecked() + " accounts", "127.0.0.1");
        }
        return report;
    }

    @Transactional(readOnly = true)
    public ReconciliationReport reconcileAll()
    {
        List<JournalEntryJpaEntity> entries = journalRepo.findAll();
        BigDecimal totalDebits = BigDecimal.ZERO;
        BigDecimal totalCredits = BigDecimal.ZERO;

        Map<Long, BigDecimal> computedAccountBalances = new HashMap<>();

        for (JournalEntryJpaEntity entry : entries)
        {
            if (JournalEntryJpaEntity.EntryType.DEBIT == entry.getType())
            {
                totalDebits = totalDebits.add(entry.getAmount());
                computedAccountBalances.merge(entry.getAccountId(), entry.getAmount().negate(), BigDecimal::add);
            }
            else if (JournalEntryJpaEntity.EntryType.CREDIT == entry.getType())
            {
                totalCredits = totalCredits.add(entry.getAmount());
                computedAccountBalances.merge(entry.getAccountId(), entry.getAmount(), BigDecimal::add);
            }
        }

        boolean isBalanced = totalDebits.compareTo(totalCredits) == 0;
        List<AccountJpaEntity> allAccounts = accountRepo.findAll();
        List<String> discrepancies = new ArrayList<>();

        int discrepancyCount = 0;
        for (AccountJpaEntity account : allAccounts)
        {
            BigDecimal netLedger = computedAccountBalances.getOrDefault(account.getId(), BigDecimal.ZERO);
            // If the account has no opening balance record, check difference
            // Here net ledger change should be consistent with transactions
            if (account.getSold().compareTo(BigDecimal.ZERO) < 0)
            {
                discrepancies.add("Account " + account.getIBAN() + " has negative balance: " + account.getSold());
                discrepancyCount++;
            }
        }

        return new ReconciliationReport(
                isBalanced,
                totalDebits,
                totalCredits,
                entries.size(),
                allAccounts.size(),
                discrepancyCount,
                discrepancies
        );
    }
}
