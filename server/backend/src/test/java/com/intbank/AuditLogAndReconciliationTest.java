package com.intbank;

import com.intbank.infrastructure.persistence.entity.AuditLogJpaEntity;
import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.AuditLogJpaRepository;
import com.intbank.infrastructure.persistence.repository.JournalEntryJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.LedgerReconciliationService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AuditLogAndReconciliationTest
{

    @Mock
    private AuditLogJpaRepository auditRepo;

    @Mock
    private JournalEntryJpaRepository journalRepo;

    @Mock
    private AccountJpaRepository accountRepo;

    @Test
    void testAuditLog_HashChainIntegrity()
    {
        AuditLogService auditLogService = new AuditLogService(auditRepo);

        when(auditRepo.findTopByOrderByIdDesc()).thenReturn(Optional.empty());

        auditLogService.log(1L, "LOGIN", "User logged in", "192.168.1.10");

        verify(auditRepo).save(argThat(entry ->
                entry.getPreviousHash().equals("0000000000000000000000000000000000000000000000000000000000000000") &&
                entry.getCurrentHash() != null && entry.getCurrentHash().length() == 64
        ));
    }

    @Test
    void testLedgerReconciliation_BalancedEntries()
    {
        AuditLogService auditLogService = new AuditLogService(auditRepo);
        LedgerReconciliationService reconciliationService =
                new LedgerReconciliationService(journalRepo, accountRepo, auditLogService);

        JournalEntryJpaEntity debit = new JournalEntryJpaEntity();
        debit.setAccountId(1L);
        debit.setType("DEBIT");
        debit.setAmount(BigDecimal.valueOf(250));

        JournalEntryJpaEntity credit = new JournalEntryJpaEntity();
        credit.setAccountId(2L);
        credit.setType("CREDIT");
        credit.setAmount(BigDecimal.valueOf(250));

        when(journalRepo.findAll()).thenReturn(List.of(debit, credit));
        when(accountRepo.findAll()).thenReturn(Collections.emptyList());

        var report = reconciliationService.reconcileAll();

        assertTrue(report.isBalanced());
        assertEquals(BigDecimal.valueOf(250), report.totalDebits());
        assertEquals(BigDecimal.valueOf(250), report.totalCredits());
        assertEquals(0, report.accountDiscrepancies());
    }
}
