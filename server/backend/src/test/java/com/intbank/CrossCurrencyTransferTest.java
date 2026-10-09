package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.InitiateTransferUseCase;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.AccountRepository.AccountProjection;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.JournalEntryJpaRepository;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.infrastructure.security.AuthenticatedClient;
import com.intbank.service.AmlVelocityService;
import com.intbank.service.AuditLogService;
import com.intbank.service.IdempotencyService;
import com.intbank.service.LedgerReconciliationService;
import com.intbank.service.NotificationService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Regression for audit finding F1: a RON transfer into a EUR account used to credit
 * the receiver 10,000 EUR for 10,000 RON (money creation).
 */
@ExtendWith(MockitoExtension.class)
class CrossCurrencyTransferTest
{

    private static final String RON_IBAN = "RO49INTB0000000000000010";
    private static final String EUR_IBAN = "RO49INTB0001EUR3F9A01BC";

    @Mock private AccountRepository accountRepository;
    @Mock private TransferRepository transferRepository;
    @Mock private LedgerRepository ledgerRepository;
    @Mock private OutboxJpaRepository outboxRepo;
    @Mock private NotificationService notificationService;
    @Mock private EventPublisher eventPublisher;
    @Mock private IdempotencyService idempotencyService;
    @Mock private AmlVelocityService amlVelocityService;
    @Mock private AuditLogService auditLogService;

    @AfterEach
    void clearSecurityContext()
    {
        SecurityContextHolder.clearContext();
    }

    @Test
    void processing_neverCreditsAForeignCurrencyAccountOneToOne()
    {
        when(transferRepository.findById("tx-fx")).thenReturn(Optional.empty());
        when(accountRepository.runInTransaction(any())).thenAnswer(i -> ((Supplier<?>) i.getArgument(0)).get());
        when(accountRepository.findByIdWithLock("1"))
                .thenReturn(Optional.of(new AccountProjection("1", 1L, RON_IBAN, "RON", new BigDecimal("10000.00"))));
        when(accountRepository.findByIdWithLock("2"))
                .thenReturn(Optional.of(new AccountProjection("2", 2L, EUR_IBAN, "EUR", BigDecimal.ZERO)));

        new ProcessTransferUseCase(accountRepository, transferRepository, ledgerRepository, outboxRepo,
                new ObjectMapper(), notificationService, null)
                .execute(new TransferInitiatedEvent("tx-fx", "1", "2", RON_IBAN, EUR_IBAN,
                        new BigDecimal("10000"), "RON", "probe", Instant.now()));

        verify(accountRepository, never()).updateBalance(anyString(), any());
        verify(ledgerRepository, never()).postEntry(anyString(), anyLong(), anyString(), any(), anyString());
        verify(transferRepository).updateStatus(eq("tx-fx"), eq(TransferStatus.FAILED), any());
    }

    @Test
    void initiation_rejectsDestinationInAnotherCurrencyBeforeAnyMoneyMoves()
    {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new AuthenticatedClient("device-1", 1L, List.of("ROLE_USER")), null, List.of()));
        when(accountRepository.findByIban(RON_IBAN))
                .thenReturn(Optional.of(new AccountProjection("1", 1L, RON_IBAN, "RON", new BigDecimal("10000.00"))));
        when(accountRepository.findByIban(EUR_IBAN))
                .thenReturn(Optional.of(new AccountProjection("2", 2L, EUR_IBAN, "EUR", BigDecimal.ZERO)));

        var useCase = new InitiateTransferUseCase(eventPublisher, accountRepository, transferRepository, outboxRepo,
                idempotencyService, new ObjectMapper(), amlVelocityService, auditLogService);

        BusinessRuleException error = assertThrows(BusinessRuleException.class, () -> useCase.initiate(
                new TransferUseCase.InitiateTransferRequest(RON_IBAN, EUR_IBAN, new BigDecimal("10000"), "RON",
                        "Chirie", "Ana", "Ion", "idem-1")));

        assertEquals(BusinessRuleException.CURRENCY_MISMATCH, error.code());
        verifyNoInteractions(idempotencyService, amlVelocityService, eventPublisher, outboxRepo);
    }

    @Test
    void initiation_refusesAVaultSavingsAccountAsDestination()
    {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new AuthenticatedClient("device-1", 1L, List.of("ROLE_USER")), null, List.of()));
        String vaultIban = "RO35INTBRON0000000000077";
        when(accountRepository.findByIban(RON_IBAN))
                .thenReturn(Optional.of(new AccountProjection("1", 1L, RON_IBAN, "RON", new BigDecimal("100.00"))));
        when(accountRepository.findByIban(vaultIban))
                .thenReturn(Optional.of(new AccountProjection("9", 2L, vaultIban, "RON", BigDecimal.ZERO, "SAVINGS")));

        var useCase = new InitiateTransferUseCase(eventPublisher, accountRepository, transferRepository, outboxRepo,
                idempotencyService, new ObjectMapper(), amlVelocityService, auditLogService);

        BusinessRuleException error = assertThrows(BusinessRuleException.class, () -> useCase.initiate(
                new TransferUseCase.InitiateTransferRequest(RON_IBAN, vaultIban, BigDecimal.TEN, "RON",
                        "Cadou", "Ana", "Ion", "idem-2")));
        assertEquals(BusinessRuleException.DESTINATION_NOT_FOUND, error.code());
        verifyNoInteractions(idempotencyService, outboxRepo);
    }

    @Test
    void reconciliation_flagsACurrencyThatDoesNotNetToZero()
    {
        JournalEntryJpaRepository journalRepo = mock(JournalEntryJpaRepository.class);
        AccountJpaRepository accountRepo = mock(AccountJpaRepository.class);
        // Grand totals match (100 = 100) but RON was debited and EUR credited: the old bug's footprint.
        when(journalRepo.totalsByCurrencyAndType()).thenReturn(LedgerRows.of(
                entry(1L, JournalEntryJpaEntity.EntryType.DEBIT, "100.00", "RON"),
                entry(2L, JournalEntryJpaEntity.EntryType.CREDIT, "100.00", "EUR")));

        var report = new LedgerReconciliationService(journalRepo, accountRepo, auditLogService).reconcileAll();

        assertFalse(report.isBalanced());
        assertTrue(report.discrepancyDetails().stream().anyMatch(d -> d.contains("RON")));
        assertTrue(report.discrepancyDetails().stream().anyMatch(d -> d.contains("EUR")));
    }

    private static JournalEntryJpaEntity entry(Long accountId, JournalEntryJpaEntity.EntryType type, String amount, String currency)
    {
        JournalEntryJpaEntity e = new JournalEntryJpaEntity();
        e.setTransferId("tx");
        e.setAccountId(accountId);
        e.setType(type);
        e.setAmount(new BigDecimal(amount));
        e.setCurrency(currency);
        return e;
    }
}
