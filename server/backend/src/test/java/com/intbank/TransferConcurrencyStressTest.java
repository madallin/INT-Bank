package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.service.NotificationService;
import com.intbank.service.RedlockDistributedLockService;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

public class TransferConcurrencyStressTest
{

    @Test
    void twentyConcurrentTransfersAllowExactlyOneDebit() throws Exception
    {
        final String senderId = "1";
        final String receiverId = "2";
        final String senderIban = "RO49AAAA1B31007593840000";
        final String receiverIban = "RO49BBBB1B31007593841111";
        final BigDecimal amount = new BigDecimal("100.00");
        final int threadCount = 20;

        final InMemoryAccountRepository accountRepository = new InMemoryAccountRepository();
        accountRepository.seed(new AccountRepository.AccountProjection(
                senderId, 10L, senderIban, "RON", new BigDecimal("100.00")));
        accountRepository.seed(new AccountRepository.AccountProjection(
                receiverId, 20L, receiverIban, "RON", new BigDecimal("0.00")));

        final InMemoryTransferRepository transferRepository = new InMemoryTransferRepository();
        final RecordingLedgerRepository ledgerRepository = new RecordingLedgerRepository();

        final OutboxJpaRepository outboxRepo = mock(OutboxJpaRepository.class);
        final NotificationService notificationService = mock(NotificationService.class);
        final RedlockDistributedLockService lockService = mock(RedlockDistributedLockService.class);
        when(lockService.acquireLock(anyString(), anyLong())).thenReturn(true);

        final ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository, outboxRepo,
                new ObjectMapper(), notificationService, lockService);

        final ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        final CountDownLatch startGate = new CountDownLatch(1);
        final CountDownLatch finishGate = new CountDownLatch(threadCount);
        final AtomicReference<Throwable> unexpectedError = new AtomicReference<>();

        try
        {
            for (int i = 0; i < threadCount; i++)
            {
                final int index = i;
                executor.submit(() ->
                {
                    try
                    {
                        startGate.await();
                        final TransferInitiatedEvent event = new TransferInitiatedEvent(
                                "stress-" + index, senderId, receiverId, senderIban, receiverIban,
                                amount, "RON", "concurrency stress", Instant.now());
                        useCase.execute(event);
                    }
                    catch (Throwable error)
                    {
                        unexpectedError.compareAndSet(null, error);
                    }
                    finally
                    {
                        finishGate.countDown();
                    }
                });
            }

            startGate.countDown();
            assertTrue(finishGate.await(30, TimeUnit.SECONDS), "worker threads did not finish in time");
        }
        finally
        {
            executor.shutdownNow();
        }

        assertNull(unexpectedError.get(), "unexpected worker error: " + unexpectedError.get());

        assertEquals(1L, transferRepository.countByStatus(TransferStatus.COMPLETED),
                "exactly one transfer must complete");
        assertEquals(19L, transferRepository.countByStatus(TransferStatus.FAILED),
                "the remaining nineteen transfers must fail");

        final BigDecimal senderBalance = accountRepository.balanceOf(senderId).setScale(2, RoundingMode.HALF_EVEN);
        assertEquals(new BigDecimal("0.00"), senderBalance, "sender balance must be exactly zero");
        assertEquals(new BigDecimal("100.00"),
                accountRepository.balanceOf(receiverId).setScale(2, RoundingMode.HALF_EVEN),
                "receiver balance must reflect the single successful credit");

        for (final BigDecimal observed : accountRepository.balanceHistory())
        {
            assertTrue(observed.signum() >= 0, "an account balance went negative: " + observed);
        }

        final BigDecimal totalDebits = ledgerRepository.totalFor("DEBIT").setScale(2, RoundingMode.HALF_EVEN);
        final BigDecimal totalCredits = ledgerRepository.totalFor("CREDIT").setScale(2, RoundingMode.HALF_EVEN);
        assertEquals(new BigDecimal("100.00"), totalDebits, "total debits must equal the single transfer amount");
        assertEquals(new BigDecimal("100.00"), totalCredits, "total credits must equal the single transfer amount");
        assertEquals(totalDebits, totalCredits, "double-entry ledger debits must strictly equal credits");
    }

    static final class InMemoryAccountRepository implements AccountRepository
    {

        private final Map<String, AccountState> accounts = new ConcurrentHashMap<>();
        private final Map<String, ReentrantLock> accountLocks = new ConcurrentHashMap<>();
        private final ThreadLocal<List<ReentrantLock>> heldLocks = ThreadLocal.withInitial(ArrayList::new);
        private final List<BigDecimal> balanceHistory = Collections.synchronizedList(new ArrayList<>());

        void seed(AccountProjection projection)
        {
            accounts.put(projection.id(), new AccountState(
                    projection.id(), projection.userId(), projection.iban(), projection.moneda(), projection.sold()));
            accountLocks.put(projection.id(), new ReentrantLock());
            balanceHistory.add(projection.sold());
        }

        BigDecimal balanceOf(String accountId)
        {
            final AccountState state = accounts.get(accountId);
            return state == null ? null : state.sold.get();
        }

        List<BigDecimal> balanceHistory()
        {
            return new ArrayList<>(balanceHistory);
        }

        @Override
        public Optional<AccountProjection> findByIban(String iban)
        {
            return accounts.values().stream()
                    .filter(state -> state.iban.equals(iban))
                    .findFirst()
                    .map(AccountState::toProjection);
        }

        @Override
        public Optional<AccountProjection> findByIdWithLock(String accountId)
        {
            final AccountState state = accounts.get(accountId);
            if (state == null)
            {
                return Optional.empty();
            }
            final ReentrantLock lock = accountLocks.computeIfAbsent(accountId, key -> new ReentrantLock());
            lock.lock();
            heldLocks.get().add(lock);
            balanceHistory.add(state.sold.get());
            return Optional.of(state.toProjection());
        }

        @Override
        public void updateBalance(String accountId, BigDecimal newBalance)
        {
            final AccountState state = accounts.get(accountId);
            if (state != null)
            {
                state.sold.set(newBalance);
                balanceHistory.add(newBalance);
            }
        }

        @Override
        public <T> T runInTransaction(Supplier<T> block)
        {
            try
            {
                return block.get();
            }
            finally
            {
                releaseHeldLocks();
            }
        }

        private void releaseHeldLocks()
        {
            final List<ReentrantLock> locks = heldLocks.get();
            for (int i = locks.size() - 1; i >= 0; i--)
            {
                locks.get(i).unlock();
            }
            locks.clear();
        }

        static final class AccountState
        {

            private final String id;
            private final Long userId;
            private final String iban;
            private final String moneda;
            private final AtomicReference<BigDecimal> sold;

            AccountState(String id, Long userId, String iban, String moneda, BigDecimal sold)
            {
                this.id = id;
                this.userId = userId;
                this.iban = iban;
                this.moneda = moneda;
                this.sold = new AtomicReference<>(sold);
            }

            AccountProjection toProjection()
            {
                return new AccountProjection(id, userId, iban, moneda, sold.get());
            }
        }
    }

    static final class InMemoryTransferRepository implements TransferRepository
    {

        private final Map<String, TransferProjection> store = new ConcurrentHashMap<>();

        @Override
        public Optional<TransferProjection> findById(String transferId)
        {
            return Optional.ofNullable(store.get(transferId));
        }

        @Override
        public void save(TransferProjection transfer)
        {
            store.put(transfer.id(), transfer);
        }

        @Override
        public void updateStatus(String transferId, TransferStatus status, Instant completedAt)
        {
            final TransferProjection existing = store.get(transferId);
            if (existing != null)
            {
                store.put(transferId, new TransferProjection(
                        existing.id(), existing.fromAccountId(), existing.toAccountId(), existing.amount(),
                        existing.currency(), existing.reason(), status, existing.initiatedAt(), completedAt,
                        existing.failureReason()));
            }
        }

        @Override
        public void updateStatusWithEntity(String transferId, TransferStatus status, Instant completedAt,
                                           String failureReason)
        {
            final TransferProjection existing = store.get(transferId);
            if (existing != null)
            {
                store.put(transferId, new TransferProjection(
                        existing.id(), existing.fromAccountId(), existing.toAccountId(), existing.amount(),
                        existing.currency(), existing.reason(), status, existing.initiatedAt(), completedAt,
                        failureReason));
            }
        }

        long countByStatus(TransferStatus status)
        {
            return store.values().stream().filter(transfer -> transfer.status() == status).count();
        }
    }

    static final class RecordingLedgerRepository implements LedgerRepository
    {

        private final List<LedgerEntry> entries = Collections.synchronizedList(new ArrayList<>());

        @Override
        public void postEntry(String transferId, Long accountId, String entryType, BigDecimal amount, String currency)
        {
            entries.add(new LedgerEntry(transferId, accountId, entryType, amount, currency));
        }

        BigDecimal totalFor(String entryType)
        {
            return entries.stream()
                    .filter(entry -> entry.type().equals(entryType))
                    .map(LedgerEntry::amount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
        }

        record LedgerEntry(String transferId, Long accountId, String type, BigDecimal amount, String currency)
        {
        }
    }
}
