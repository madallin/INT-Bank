package com.intbank;

import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.entity.Account;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.Iban;
import com.intbank.core.domain.vo.Money;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.service.NotificationService;
import com.intbank.service.RedlockDistributedLockService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.RedisScript;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class RedlockDistributedLockServiceTest
{

    @Mock
    private RedisTemplate<String, String> redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private TransferRepository transferRepository;

    @Mock
    private LedgerRepository ledgerRepository;

    @Mock
    private OutboxJpaRepository outboxRepo;

    @Mock
    private NotificationService notificationService;

    private RedlockDistributedLockService lockService;
    private ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp()
    {
        lenient().when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        lockService = new RedlockDistributedLockService(redisTemplate);
    }

    @Test
    void testAcquireLock_Success()
    {
        when(valueOperations.setIfAbsent(eq("account:lock:acc-100"), anyString(), any(Duration.class)))
                .thenReturn(true);

        boolean acquired = lockService.acquireLock("account:lock:acc-100", 5);

        assertTrue(acquired);
        verify(valueOperations).setIfAbsent(eq("account:lock:acc-100"), anyString(), eq(Duration.ofSeconds(5)));
    }

    @Test
    void testAcquireLock_TimeoutFails()
    {
        when(valueOperations.setIfAbsent(eq("account:lock:acc-100"), anyString(), any(Duration.class)))
                .thenReturn(false);

        // Timeout 0 triggers single attempt without waiting
        boolean acquired = lockService.acquireLock("account:lock:acc-100", 0);

        assertFalse(acquired);
    }

    @Test
    void testAcquireLock_BlankKey_ReturnsFalse()
    {
        assertFalse(lockService.acquireLock(null, 5));
        assertFalse(lockService.acquireLock("  ", 5));
    }

    @Test
    void testReleaseLock_WithStoredToken_ExecutesLuaScript()
    {
        when(valueOperations.setIfAbsent(eq("account:lock:acc-200"), anyString(), any(Duration.class)))
                .thenReturn(true);
        when(redisTemplate.execute(any(RedisScript.class), anyList(), anyString()))
                .thenReturn(1L);

        assertTrue(lockService.acquireLock("account:lock:acc-200", 5));
        lockService.releaseLock("account:lock:acc-200");

        verify(redisTemplate).execute(any(RedisScript.class), eq(List.of("account:lock:acc-200")), anyString());
    }

    @Test
    void testReleaseLock_FallbackDirectDelete()
    {
        when(redisTemplate.delete("account:lock:acc-300")).thenReturn(true);

        // No prior acquire on this thread
        lockService.releaseLock("account:lock:acc-300");

        verify(redisTemplate).delete("account:lock:acc-300");
    }

    @Test
    void testProcessTransferUseCase_IntegratesDistributedLock()
    {
        RedlockDistributedLockService mockLockService = mock(RedlockDistributedLockService.class);
        when(mockLockService.acquireLock(eq("account:lock:acc-1"), anyLong())).thenReturn(true);

        ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository,
                outboxRepo, objectMapper, notificationService, mockLockService
        );

        when(transferRepository.findById("tx-123")).thenReturn(Optional.empty());

        Account sender = new Account("acc-1", new Iban("RO49AAAA1B31007593840001"), new Money(BigDecimal.valueOf(1000), "RON"), 1L);
        Account receiver = new Account("acc-2", new Iban("RO49BBBB1B31007593840002"), new Money(BigDecimal.valueOf(500), "RON"), 2L);

        doAnswer(invocation -> {
            Runnable action = invocation.getArgument(0);
            action.run();
            return null;
        }).when(accountRepository).runInTransaction(any());

        when(accountRepository.findByIdWithLock("acc-1")).thenReturn(Optional.of(sender));
        when(accountRepository.findByIdWithLock("acc-2")).thenReturn(Optional.of(receiver));

        TransferInitiatedEvent event = new TransferInitiatedEvent(
                "tx-123", "acc-1", "acc-2",
                "RO49AAAA1B31007593840001", "RO49BBBB1B31007593840002",
                BigDecimal.valueOf(100), "RON", "Test Transfer", Instant.now()
        );

        useCase.execute(event);

        // Verify lock was acquired on account:lock:acc-1
        verify(mockLockService).acquireLock(eq("account:lock:acc-1"), eq(15L));
        // Verify lock was released
        verify(mockLockService).releaseLock(eq("account:lock:acc-1"));
        // Verify transfer was saved
        verify(transferRepository).save(any(TransferRepository.TransferProjection.class));
        verify(accountRepository).updateBalance("acc-1", BigDecimal.valueOf(900).setScale(2));
        verify(accountRepository).updateBalance("acc-2", BigDecimal.valueOf(600).setScale(2));
    }

    @Test
    void testProcessTransferUseCase_FailsWhenLockCannotBeAcquired()
    {
        RedlockDistributedLockService mockLockService = mock(RedlockDistributedLockService.class);
        when(mockLockService.acquireLock(eq("account:lock:acc-1"), anyLong())).thenReturn(false);

        ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository,
                outboxRepo, objectMapper, notificationService, mockLockService
        );

        when(transferRepository.findById("tx-999")).thenReturn(Optional.empty());

        TransferInitiatedEvent event = new TransferInitiatedEvent(
                "tx-999", "acc-1", "acc-2",
                "RO49AAAA1B31007593840001", "RO49BBBB1B31007593840002",
                BigDecimal.valueOf(50), "RON", "Contested Transfer", Instant.now()
        );

        assertThrows(IllegalStateException.class, () -> useCase.execute(event));
        verify(mockLockService).acquireLock(eq("account:lock:acc-1"), eq(15L));
        verify(mockLockService, never()).releaseLock(anyString());
        verify(accountRepository, never()).runInTransaction(any());
    }
}
