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

    /**
     * Checks the journal with aggregates computed by the database (it never loads the entries):
     * debits equal credits in every currency, and no account is overdrawn.
     */
    @Transactional(readOnly = true)
    public ReconciliationReport reconcileAll()
    {
        BigDecimal totalDebits = BigDecimal.ZERO;
        BigDecimal totalCredits = BigDecimal.ZERO;
        long totalEntries = 0;
        // Debits minus credits per currency; every currency must net to zero on its own,
        // otherwise a cross-currency posting could hide behind a matching grand total.
        Map<String, BigDecimal> netByCurrency = new TreeMap<>();

        for (Object[] row : journalRepo.totalsByCurrencyAndType())
        {
            String currency = (String) row[0];
            JournalEntryJpaEntity.EntryType type = (JournalEntryJpaEntity.EntryType) row[1];
            BigDecimal sum = row[2] != null ? (BigDecimal) row[2] : BigDecimal.ZERO;
            totalEntries += ((Number) row[3]).longValue();
            if (type == JournalEntryJpaEntity.EntryType.DEBIT)
            {
                totalDebits = totalDebits.add(sum);
                netByCurrency.merge(currency, sum, BigDecimal::add);
            }
            else if (type == JournalEntryJpaEntity.EntryType.CREDIT)
            {
                totalCredits = totalCredits.add(sum);
                netByCurrency.merge(currency, sum.negate(), BigDecimal::add);
            }
        }

        List<String> discrepancies = new ArrayList<>();
        boolean isBalanced = totalDebits.compareTo(totalCredits) == 0;
        for (Map.Entry<String, BigDecimal> currency : netByCurrency.entrySet())
        {
            if (currency.getValue().signum() != 0)
            {
                isBalanced = false;
                discrepancies.add("Currency " + currency.getKey() + " is unbalanced: debits - credits = " + currency.getValue());
            }
        }

        List<AccountJpaEntity> overdrawn = accountRepo.findBySoldLessThan(BigDecimal.ZERO);
        for (AccountJpaEntity account : overdrawn)
        {
            discrepancies.add("Account " + account.getIBAN() + " has negative balance: " + account.getSold());
        }

        return new ReconciliationReport(
                isBalanced,
                totalDebits,
                totalCredits,
                (int) Math.min(Integer.MAX_VALUE, totalEntries),
                (int) Math.min(Integer.MAX_VALUE, accountRepo.count()),
                overdrawn.size(),
                discrepancies
        );
    }
}
