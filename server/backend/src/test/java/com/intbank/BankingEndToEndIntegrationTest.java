package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.InitiateTransferUseCase;
import com.intbank.core.domain.entity.Account;
import com.intbank.core.domain.vo.Iban;
import com.intbank.core.domain.vo.Money;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.*;
import com.intbank.infrastructure.persistence.repository.*;
import com.intbank.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BankingEndToEndIntegrationTest
{

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private TransferRepository transferRepository;

    @Mock
    private OutboxJpaRepository outboxRepo;

    @Mock
    private IdempotencyJpaRepository idempotencyRepo;

    @Mock
    private RedisTemplate<String, String> redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    @Mock
    private EventPublisher eventPublisher;

    @Mock
    private AuditLogJpaRepository auditRepo;

    @Mock
    private JournalEntryJpaRepository journalRepo;

    @Mock
    private AccountJpaRepository accountJpaRepo;

    private ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();
    private IdempotencyService idempotencyService;
    private AmlVelocityService amlVelocityService;
    private AuditLogService auditLogService;
    private LedgerReconciliationService reconciliationService;
    private InitiateTransferUseCase initiateTransferUseCase;

    private final String aliceIban = "RO49AAAA1B31007593840001";
    private final String bobIban = "RO49BBBB1B31007593840002";

    @BeforeEach
    void setUp()
    {
        signInAs(100L);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);

        idempotencyService = new IdempotencyService(idempotencyRepo, redisTemplate, objectMapper);
        amlVelocityService = new AmlVelocityService(redisTemplate);
        auditLogService = new AuditLogService(auditRepo);
        reconciliationService = new LedgerReconciliationService(journalRepo, accountJpaRepo, auditLogService);

        initiateTransferUseCase = new InitiateTransferUseCase(
                eventPublisher, accountRepository, transferRepository,
                outboxRepo, idempotencyService, objectMapper,
                amlVelocityService, auditLogService
        );
    }

    @Test
    void testCompleteBankingTransferLifecycle_CorrelatedFlow()
    {
        // 1. Setup Alice and Bob Accounts
        AccountRepository.AccountProjection alice = new AccountRepository.AccountProjection("acc-alice", 100L, aliceIban, "RON", BigDecimal.valueOf(2500));
        AccountRepository.AccountProjection bob = new AccountRepository.AccountProjection("acc-bob", 200L, bobIban, "RON", BigDecimal.valueOf(100));

        when(accountRepository.findByIban(aliceIban)).thenReturn(Optional.of(alice));
        when(accountRepository.findByIban(bobIban)).thenReturn(Optional.of(bob));

        // 2. Redis Locking & Idempotency Setup
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        when(idempotencyRepo.findByIdempotencyKey("idem-flow-001")).thenReturn(Optional.empty());

        // 3. Initiate Transfer: Alice sends 350.00 RON to Bob
        var request = new TransferUseCase.InitiateTransferRequest(
                aliceIban, bobIban, BigDecimal.valueOf(350.00), "RON",
                "Chirie Septembrie", "Bob Popescu", "Alice Ionescu", "idem-flow-001"
        );

        var response = initiateTransferUseCase.initiate(request);

        // 4. Validate Transfer Response & Status
        assertNotNull(response);
        assertEquals(TransferStatus.PENDING, response.status());
        assertNotNull(response.trackingId());

        // 5. Verify Correlated Side Effects:
        // a. Transfer record persisted in DB
        verify(transferRepository).save(argThat(proj ->
                proj.fromAccountId().equals("acc-alice") &&
                proj.toAccountId().equals("acc-bob") &&
                proj.amount().compareTo(BigDecimal.valueOf(350.00)) == 0
        ));

        // b. Transactional Outbox event queued
        verify(outboxRepo).save(any(OutboxJpaEntity.class));

        // c. Idempotency state marked COMPLETED in database
        verify(idempotencyRepo).save(any(IdempotencyRecordJpaEntity.class));

        // d. Cryptographic Audit Trail written
        verify(auditRepo).save(any(AuditLogJpaEntity.class));

        // 6. Simulate Double-Entry Ledger Posting for this transaction:
        JournalEntryJpaEntity debitAlice = new JournalEntryJpaEntity();
        debitAlice.setAccountId(1L);
        debitAlice.setType(JournalEntryJpaEntity.EntryType.DEBIT);
        debitAlice.setAmount(BigDecimal.valueOf(350.00));
        debitAlice.setCurrency("RON");

        JournalEntryJpaEntity creditBob = new JournalEntryJpaEntity();
        creditBob.setAccountId(2L);
        creditBob.setType(JournalEntryJpaEntity.EntryType.CREDIT);
        creditBob.setAmount(BigDecimal.valueOf(350.00));
        creditBob.setCurrency("RON");

        when(journalRepo.totalsByCurrencyAndType()).thenReturn(LedgerRows.of(debitAlice, creditBob));

        // 7. Execute General Ledger Balancing Reconciliation
        var reconReport = reconciliationService.reconcileAll();

        assertTrue(reconReport.isBalanced(), "Ledger must be balanced with total Debits == total Credits");
        assertEquals(BigDecimal.valueOf(350.00), reconReport.totalDebits());
        assertEquals(BigDecimal.valueOf(350.00), reconReport.totalCredits());
        assertEquals(0, reconReport.accountDiscrepancies());
    }

    /** Signs in as the customer that owns the source account. */
    private static void signInAs(Long userId)
    {
        org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(
                new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(
                        new com.intbank.infrastructure.security.AuthenticatedClient("test-device", userId, java.util.List.of("ROLE_USER")),
                        null, java.util.List.of()));
    }

    @org.junit.jupiter.api.AfterEach
    void signOut()
    {
        org.springframework.security.core.context.SecurityContextHolder.clearContext();
    }
}
