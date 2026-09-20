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
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.service.IdempotencyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TransferUseCaseTest
{

    @Mock
    private EventPublisher eventPublisher;

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private TransferRepository transferRepository;

    @Mock
    private OutboxJpaRepository outboxRepo;

    @Mock
    private IdempotencyService idempotencyService;

    @Mock
    private com.intbank.service.AmlVelocityService amlVelocityService;

    @Mock
    private com.intbank.service.AuditLogService auditLogService;

    private ObjectMapper objectMapper = new ObjectMapper();
    private InitiateTransferUseCase initiateTransferUseCase;

    private final String fromIban = "RO49AAAA1B31007593840000";
    private final String toIban = "RO49BBBB1B31007593841111";

    @BeforeEach
    void setUp()
    {
        when(amlVelocityService.evaluateTransfer(anyLong(), any(), any()))
                .thenReturn(new com.intbank.service.AmlVelocityService.AmlResult(
                        com.intbank.service.AmlVelocityService.RiskAssessment.PASS, false, "OK"));

        initiateTransferUseCase = new InitiateTransferUseCase(
                eventPublisher, accountRepository, transferRepository,
                outboxRepo, idempotencyService, objectMapper,
                amlVelocityService, auditLogService
        );
    }

    @Test
    void testInitiateTransfer_Success()
    {
        Account fromAccount = new Account("acc-1", new Iban(fromIban), new Money(BigDecimal.valueOf(1000), "RON"), 1L);
        Account toAccount = new Account("acc-2", new Iban(toIban), new Money(BigDecimal.valueOf(500), "RON"), 2L);

        when(accountRepository.findByIban(fromIban)).thenReturn(Optional.of(fromAccount));
        when(accountRepository.findByIban(toIban)).thenReturn(Optional.of(toAccount));
        when(idempotencyService.beginOrGet(anyString(), anyLong(), anyString()))
                .thenReturn(new IdempotencyService.Decision(IdempotencyService.Outcome.PROCEED, null));

        var request = new TransferUseCase.InitiateTransferRequest(
                fromIban, toIban, BigDecimal.valueOf(100), "RON", "Plata chirie", "Ion", "Maria", "key-123"
        );

        var response = initiateTransferUseCase.initiate(request);

        assertNotNull(response);
        assertEquals(TransferStatus.PENDING, response.status());
        assertNotNull(response.trackingId());

        verify(transferRepository).save(any(TransferRepository.TransferProjection.class));
        verify(outboxRepo).save(any(OutboxJpaEntity.class));
        verify(idempotencyService).complete(eq("key-123"), any());
    }

    @Test
    void testInitiateTransfer_ZeroAmount_ThrowsException()
    {
        Account fromAccount = new Account("acc-1", new Iban(fromIban), new Money(BigDecimal.valueOf(1000), "RON"), 1L);
        Account toAccount = new Account("acc-2", new Iban(toIban), new Money(BigDecimal.valueOf(500), "RON"), 2L);

        when(accountRepository.findByIban(fromIban)).thenReturn(Optional.of(fromAccount));
        when(accountRepository.findByIban(toIban)).thenReturn(Optional.of(toAccount));
        when(idempotencyService.beginOrGet(anyString(), anyLong(), anyString()))
                .thenReturn(new IdempotencyService.Decision(IdempotencyService.Outcome.PROCEED, null));

        var request = new TransferUseCase.InitiateTransferRequest(
                fromIban, toIban, BigDecimal.ZERO, "RON", "Plata chirie", "Ion", "Maria", "key-123"
        );

        assertThrows(IllegalArgumentException.class, () -> initiateTransferUseCase.initiate(request));
        verify(idempotencyService).fail(eq("key-123"), anyString());
    }

    @Test
    void testInitiateTransfer_WithDistributedLock_AcquiresAndReleasesLock()
    {
        com.intbank.service.RedlockDistributedLockService mockLock = mock(com.intbank.service.RedlockDistributedLockService.class);
        when(mockLock.acquireLock(eq("account:lock:acc-1"), anyLong())).thenReturn(true);

        InitiateTransferUseCase customUseCase = new InitiateTransferUseCase(
                eventPublisher, accountRepository, transferRepository,
                outboxRepo, idempotencyService, objectMapper,
                amlVelocityService, auditLogService, mockLock
        );

        Account fromAccount = new Account("acc-1", new Iban(fromIban), new Money(BigDecimal.valueOf(1000), "RON"), 1L);
        Account toAccount = new Account("acc-2", new Iban(toIban), new Money(BigDecimal.valueOf(500), "RON"), 2L);

        when(accountRepository.findByIban(fromIban)).thenReturn(Optional.of(fromAccount));
        when(accountRepository.findByIban(toIban)).thenReturn(Optional.of(toAccount));
        when(idempotencyService.beginOrGet(anyString(), anyLong(), anyString()))
                .thenReturn(new IdempotencyService.Decision(IdempotencyService.Outcome.PROCEED, null));

        var request = new TransferUseCase.InitiateTransferRequest(
                fromIban, toIban, BigDecimal.valueOf(100), "RON", "Plata chirie", "Ion", "Maria", "key-lock-test"
        );

        var response = customUseCase.initiate(request);

        assertNotNull(response);
        verify(mockLock).acquireLock(eq("account:lock:acc-1"), eq(10L));
        verify(mockLock).releaseLock(eq("account:lock:acc-1"));
    }

    @Test
    void testInitiateTransfer_LockContested_ThrowsIllegalStateException()
    {
        com.intbank.service.RedlockDistributedLockService mockLock = mock(com.intbank.service.RedlockDistributedLockService.class);
        when(mockLock.acquireLock(eq("account:lock:acc-1"), anyLong())).thenReturn(false);

        InitiateTransferUseCase customUseCase = new InitiateTransferUseCase(
                eventPublisher, accountRepository, transferRepository,
                outboxRepo, idempotencyService, objectMapper,
                amlVelocityService, auditLogService, mockLock
        );

        Account fromAccount = new Account("acc-1", new Iban(fromIban), new Money(BigDecimal.valueOf(1000), "RON"), 1L);
        Account toAccount = new Account("acc-2", new Iban(toIban), new Money(BigDecimal.valueOf(500), "RON"), 2L);

        when(accountRepository.findByIban(fromIban)).thenReturn(Optional.of(fromAccount));
        when(accountRepository.findByIban(toIban)).thenReturn(Optional.of(toAccount));
        when(idempotencyService.beginOrGet(anyString(), anyLong(), anyString()))
                .thenReturn(new IdempotencyService.Decision(IdempotencyService.Outcome.PROCEED, null));

        var request = new TransferUseCase.InitiateTransferRequest(
                fromIban, toIban, BigDecimal.valueOf(100), "RON", "Plata chirie", "Ion", "Maria", "key-lock-contested"
        );

        assertThrows(IllegalStateException.class, () -> customUseCase.initiate(request));
        verify(mockLock).acquireLock(eq("account:lock:acc-1"), eq(10L));
        verify(mockLock, never()).releaseLock(anyString());
    }
}
