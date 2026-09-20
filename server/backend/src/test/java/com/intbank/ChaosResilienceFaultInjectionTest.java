package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.service.NotificationService;
import com.intbank.service.OutboxProcessorService;
import com.intbank.service.RedlockDistributedLockService;
import org.junit.jupiter.api.Test;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.kafka.KafkaException;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Chaos engineering fault injection tests.
 *
 * These tests deliberately inject catastrophic infrastructure failures (Redis lock
 * partition, Kafka broker crash, database lock timeout) into the money transfer path
 * and prove the two core resilience invariants:
 *   1. Graceful degradation: no exception from a downstream dependency results in a
 *      partial debit/credit or a half-written transfer.
 *   2. Conservation of money: the aggregate balance (sender + receiver) is byte-for-byte
 *      identical before and after every injected failure (zero drift).
 *
 * The tests are fully deterministic: no Spring context, no database, no Redis, no Kafka,
 * no sleeping and no randomness.
 */
public class ChaosResilienceFaultInjectionTest
{

    private static final String SENDER_ID = "1";
    private static final String RECEIVER_ID = "2";
    private static final String SENDER_IBAN = "RO49AAAA1B31007593840001";
    private static final String RECEIVER_IBAN = "RO49BBBB1B31007593840002";
    private static final String CURRENCY = "RON";
    private static final Long SENDER_USER_ID = 10L;
    private static final Long RECEIVER_USER_ID = 20L;
    private static final BigDecimal SENDER_START = new BigDecimal("1000.00");
    private static final BigDecimal RECEIVER_START = new BigDecimal("500.00");
    private static final BigDecimal TRANSFER_AMOUNT = new BigDecimal("100.00");
    private static final Instant FIXED_INSTANT = Instant.parse("2026-01-01T00:00:00Z");

    // ----------------------------------------------------------------------------------
    // Scenario 1: Redis cluster network partition / lock acquisition failure.
    // ----------------------------------------------------------------------------------

    @Test
    void scenario1_redisFailure_acquireLockThrows_rejectsTransferWithoutBalanceMutation()
    {
        DriftReport report = runRedisFailureScenario();

        assertEquals("scenario1-redis-failure", report.scenario());
        assertEquals(0, report.drift().compareTo(BigDecimal.ZERO.setScale(2)));
    }

    @Test
    void scenario1b_redisFailure_lockContended_rejectsTransferWithoutBalanceMutation()
    {
        DriftReport report = runRedisLockContentionScenario();

        assertEquals("scenario1b-redis-lock-contention", report.scenario());
        assertEquals(0, report.drift().compareTo(BigDecimal.ZERO.setScale(2)));
    }

    private DriftReport runRedisFailureScenario()
    {
        final InMemoryAccountRepository accountRepository = seededRepository();
        final TransferRepository transferRepository = mock(TransferRepository.class);
        final LedgerRepository ledgerRepository = mock(LedgerRepository.class);
        final RedlockDistributedLockService lockService = mock(RedlockDistributedLockService.class);

        when(lockService.acquireLock(eq("account:lock:" + SENDER_ID), anyLong()))
                .thenThrow(new RuntimeException("simulated Redis timeout during lock acquisition"));

        final ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository,
                mock(OutboxJpaRepository.class), jsonMapper(), mock(NotificationService.class), lockService);

        final TransferInitiatedEvent event = sampleEvent("chaos-redis-timeout");
        final BigDecimal totalBefore = total(accountRepository);

        assertThrows(RuntimeException.class, () -> useCase.execute(event));

        final BigDecimal totalAfter = total(accountRepository);
        assertZeroDrift("scenario1-redis-failure", totalBefore, totalAfter);
        assertBalancesUnchanged(accountRepository);
        assertEquals(0, accountRepository.updateBalanceInvocations(),
                "no balance may be written when the Redis lock cannot be acquired");
        assertEquals(0, accountRepository.runInTransactionInvocations(),
                "no transaction may be opened when the Redis lock cannot be acquired");
        verify(ledgerRepository, never())
                .postEntry(anyString(), anyLong(), anyString(), any(BigDecimal.class), anyString());
        verify(transferRepository, never()).save(any(TransferRepository.TransferProjection.class));
        verify(lockService, never()).releaseLock(anyString());

        return new DriftReport("scenario1-redis-failure", totalBefore, totalAfter);
    }

    private DriftReport runRedisLockContentionScenario()
    {
        final InMemoryAccountRepository accountRepository = seededRepository();
        final TransferRepository transferRepository = mock(TransferRepository.class);
        final LedgerRepository ledgerRepository = mock(LedgerRepository.class);
        final RedlockDistributedLockService lockService = mock(RedlockDistributedLockService.class);

        when(lockService.acquireLock(eq("account:lock:" + SENDER_ID), anyLong())).thenReturn(false);

        final ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository,
                mock(OutboxJpaRepository.class), jsonMapper(), mock(NotificationService.class), lockService);

        final TransferInitiatedEvent event = sampleEvent("chaos-redis-contention");
        final BigDecimal totalBefore = total(accountRepository);

        assertThrows(IllegalStateException.class, () -> useCase.execute(event));

        final BigDecimal totalAfter = total(accountRepository);
        assertZeroDrift("scenario1b-redis-lock-contention", totalBefore, totalAfter);
        assertBalancesUnchanged(accountRepository);
        assertEquals(0, accountRepository.updateBalanceInvocations(),
                "a contended lock must fail fast before any balance write");
        verify(ledgerRepository, never())
                .postEntry(anyString(), anyLong(), anyString(), any(BigDecimal.class), anyString());
        verify(transferRepository, never()).save(any(TransferRepository.TransferProjection.class));
        verify(lockService, never()).releaseLock(anyString());

        return new DriftReport("scenario1b-redis-lock-contention", totalBefore, totalAfter);
    }

    // ----------------------------------------------------------------------------------
    // Scenario 2: Kafka broker crash during outbox dispatch, then broker recovery.
    // ----------------------------------------------------------------------------------

    @Test
    void scenario2_kafkaBrokerCrash_thenRecovery_preservesOutboxAndBalance() throws Exception
    {
        DriftReport report = runKafkaBrokerCrashScenario();

        assertEquals("scenario2-kafka-crash-and-recovery", report.scenario());
        assertEquals(0, report.drift().compareTo(BigDecimal.ZERO.setScale(2)));
    }

    @SuppressWarnings("unchecked")
    private DriftReport runKafkaBrokerCrashScenario() throws Exception
    {
        final InMemoryAccountRepository accountRepository = seededRepository();
        final BigDecimal totalBefore = total(accountRepository);

        final OutboxJpaRepository outboxRepo = mock(OutboxJpaRepository.class);
        final KafkaTemplate<String, String> kafkaTemplate = mock(KafkaTemplate.class);
        final ProcessTransferUseCase processTransferUseCase = mock(ProcessTransferUseCase.class);
        final ObjectMapper objectMapper = jsonMapper();

        doThrow(new IllegalStateException("simulated local fallback unavailable"))
                .when(processTransferUseCase).execute(any(TransferInitiatedEvent.class));

        final OutboxProcessorService processor = new OutboxProcessorService(
                outboxRepo, kafkaTemplate, processTransferUseCase, objectMapper, true);

        final TransferInitiatedEvent event = sampleEvent("chaos-kafka-crash");
        final OutboxJpaEntity message = new OutboxJpaEntity();
        message.setId(1L);
        message.setTopic(TransferInitiatedEvent.EVENT_NAME);
        message.setPartitionKey(event.trackingId());
        message.setPayload(initiatedEventPayload(objectMapper, event));
        message.setStatus("PENDING");
        message.setRetryCount(0);
        message.setMaxRetries(5);
        message.setCreatedAt(FIXED_INSTANT);

        when(outboxRepo.findTop100ByStatusAndRetryCountLessThanOrderByCreatedAtAsc("PENDING", 5))
                .thenReturn(List.of(message));
        when(kafkaTemplate.send(eq(TransferInitiatedEvent.EVENT_NAME), anyString(), anyString()))
                .thenThrow(new KafkaException("simulated Kafka broker crash"));

        // Phase 1: broker down and local fallback down. The row must stay PENDING for retry.
        processor.processOutbox();

        assertEquals("PENDING", message.getStatus(),
                "outbox row must remain PENDING while both broker and local fallback are unavailable");
        assertEquals(1, message.getRetryCount(), "retry count must be incremented exactly once");
        assertNotNull(message.getLastError(), "last error must be recorded on the outbox row");
        assertTrue(message.getLastError().contains("local fallback unavailable"),
                "last error must reflect the local fallback failure");
        verify(processTransferUseCase, times(1)).execute(any(TransferInitiatedEvent.class));
        verify(outboxRepo, times(1)).save(message);
        assertEquals(0, accountRepository.updateBalanceInvocations(),
                "no balance mutation may occur while outbox dispatch is failing");
        assertEquals(0, accountRepository.runInTransactionInvocations());

        // Phase 2: broker recovers. The very same row must now be delivered and marked SENT.
        final CompletableFuture<SendResult<String, String>> recoveredDelivery =
                CompletableFuture.completedFuture(null);
        when(kafkaTemplate.send(eq(TransferInitiatedEvent.EVENT_NAME), anyString(), anyString()))
                .thenReturn(recoveredDelivery);

        processor.processOutbox();

        assertEquals("SENT", message.getStatus(),
                "outbox row must be marked SENT once the Kafka broker recovers");
        verify(processTransferUseCase, times(1)).execute(any(TransferInitiatedEvent.class));

        final BigDecimal totalAfter = total(accountRepository);
        assertZeroDrift("scenario2-kafka-crash-and-recovery", totalBefore, totalAfter);
        assertBalancesUnchanged(accountRepository);
        assertEquals(0, accountRepository.updateBalanceInvocations());

        return new DriftReport("scenario2-kafka-crash-and-recovery", totalBefore, totalAfter);
    }

    // ----------------------------------------------------------------------------------
    // Scenario 3: Database lock timeout / deadlock during the money movement transaction.
    // ----------------------------------------------------------------------------------

    @Test
    void scenario3_databaseLockTimeoutOnRead_marksTransferFailedWithoutPartialMutation()
    {
        DriftReport report = runDatabaseLockTimeoutScenario(false);

        assertEquals("scenario3-database-lock-timeout", report.scenario());
        assertEquals(0, report.drift().compareTo(BigDecimal.ZERO.setScale(2)));
    }

    @Test
    void scenario3b_databaseTransactionTimeout_marksTransferFailedWithoutPartialMutation()
    {
        DriftReport report = runDatabaseLockTimeoutScenario(true);

        assertEquals("scenario3b-database-transaction-timeout", report.scenario());
        assertEquals(0, report.drift().compareTo(BigDecimal.ZERO.setScale(2)));
    }

    private DriftReport runDatabaseLockTimeoutScenario(boolean failInsideTransaction)
    {
        final InMemoryAccountRepository accountRepository = seededRepository();
        if (failInsideTransaction)
        {
            accountRepository.setFailOnRunInTransaction(true);
        }
        else
        {
            accountRepository.setFailOnFindByIdWithLock(true);
        }

        final TransferRepository transferRepository = mock(TransferRepository.class);
        final LedgerRepository ledgerRepository = mock(LedgerRepository.class);
        final RedlockDistributedLockService lockService = mock(RedlockDistributedLockService.class);
        when(lockService.acquireLock(eq("account:lock:" + SENDER_ID), anyLong())).thenReturn(true);

        final ProcessTransferUseCase useCase = new ProcessTransferUseCase(
                accountRepository, transferRepository, ledgerRepository,
                mock(OutboxJpaRepository.class), jsonMapper(), mock(NotificationService.class), lockService);

        final String trackingId = failInsideTransaction
                ? "chaos-db-transaction-timeout"
                : "chaos-db-lock-timeout";
        final String scenarioName = failInsideTransaction
                ? "scenario3b-database-transaction-timeout"
                : "scenario3-database-lock-timeout";
        final TransferInitiatedEvent event = sampleEvent(trackingId);
        final BigDecimal totalBefore = total(accountRepository);

        // The use case must absorb the database fault and mark the transfer FAILED.
        useCase.execute(event);

        final BigDecimal totalAfter = total(accountRepository);
        assertZeroDrift(scenarioName, totalBefore, totalAfter);
        assertBalancesUnchanged(accountRepository);
        assertEquals(0, accountRepository.updateBalanceInvocations(),
                "a database lock timeout must not produce a partial debit or credit");
        verify(ledgerRepository, never())
                .postEntry(anyString(), anyLong(), anyString(), any(BigDecimal.class), anyString());
        verify(transferRepository)
                .updateStatus(eq(trackingId), eq(TransferStatus.FAILED), any(Instant.class));
        verify(transferRepository, never())
                .updateStatusWithEntity(eq(trackingId), eq(TransferStatus.COMPLETED), any(Instant.class), any());
        verify(lockService).releaseLock(eq("account:lock:" + SENDER_ID));

        return new DriftReport(scenarioName, totalBefore, totalAfter);
    }

    // ----------------------------------------------------------------------------------
    // Aggregate conservation-of-money invariant across every injected failure.
    // ----------------------------------------------------------------------------------

    @Test
    void testAggregateZeroBalanceDriftAcrossAllScenarios() throws Exception
    {
        final List<DriftReport> reports = List.of(
                runRedisFailureScenario(),
                runRedisLockContentionScenario(),
                runKafkaBrokerCrashScenario(),
                runDatabaseLockTimeoutScenario(false),
                runDatabaseLockTimeoutScenario(true));

        BigDecimal aggregateBefore = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_EVEN);
        BigDecimal aggregateAfter = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_EVEN);
        for (final DriftReport report : reports)
        {
            assertZeroDrift(report.scenario() + " (aggregate)", report.totalBefore(), report.totalAfter());
            aggregateBefore = aggregateBefore.add(report.totalBefore());
            aggregateAfter = aggregateAfter.add(report.totalAfter());
        }

        assertEquals(0, aggregateBefore.compareTo(aggregateAfter),
                "aggregate money across all injected failures must be conserved (before="
                        + aggregateBefore + ", after=" + aggregateAfter + ")");
    }

    // ----------------------------------------------------------------------------------
    // Helpers.
    // ----------------------------------------------------------------------------------

    private static ObjectMapper jsonMapper()
    {
        final ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        return objectMapper;
    }

    private static TransferInitiatedEvent sampleEvent(String trackingId)
    {
        return new TransferInitiatedEvent(
                trackingId, SENDER_ID, RECEIVER_ID, SENDER_IBAN, RECEIVER_IBAN,
                TRANSFER_AMOUNT, CURRENCY, "chaos fault injection", FIXED_INSTANT);
    }

    private static String initiatedEventPayload(ObjectMapper objectMapper, TransferInitiatedEvent event) throws Exception
    {
        final Map<String, Object> map = new LinkedHashMap<>();
        map.put("trackingId", event.trackingId());
        map.put("fromAccountId", event.fromAccountId());
        map.put("toAccountId", event.toAccountId());
        map.put("fromIban", event.fromIban());
        map.put("toIban", event.toIban());
        map.put("amount", event.amount());
        map.put("currency", event.currency());
        map.put("description", event.description());
        map.put("timestamp", event.timestamp().toString());
        return objectMapper.writeValueAsString(map);
    }

    private static InMemoryAccountRepository seededRepository()
    {
        final InMemoryAccountRepository repository = new InMemoryAccountRepository();
        repository.seed(SENDER_ID, SENDER_USER_ID, SENDER_IBAN, CURRENCY, SENDER_START);
        repository.seed(RECEIVER_ID, RECEIVER_USER_ID, RECEIVER_IBAN, CURRENCY, RECEIVER_START);
        return repository;
    }

    private static BigDecimal total(InMemoryAccountRepository repository)
    {
        return repository.balanceOf(SENDER_ID)
                .add(repository.balanceOf(RECEIVER_ID))
                .setScale(2, RoundingMode.HALF_EVEN);
    }

    private static void assertZeroDrift(String context, BigDecimal totalBefore, BigDecimal totalAfter)
    {
        assertEquals(0, totalBefore.compareTo(totalAfter),
                context + ": total balance must be conserved (before=" + totalBefore
                        + ", after=" + totalAfter + ")");
    }

    private static void assertBalancesUnchanged(InMemoryAccountRepository repository)
    {
        assertEquals(SENDER_START, repository.balanceOf(SENDER_ID),
                "sender balance must be exactly the original value (no partial debit)");
        assertEquals(RECEIVER_START, repository.balanceOf(RECEIVER_ID),
                "receiver balance must be exactly the original value (no partial credit)");
    }

    private record DriftReport(String scenario, BigDecimal totalBefore, BigDecimal totalAfter)
    {
        BigDecimal drift()
        {
            return totalAfter.subtract(totalBefore);
        }
    }

    private static final class InMemoryAccountRepository implements AccountRepository
    {

        private final Map<String, AccountState> accounts = new LinkedHashMap<>();
        private int updateBalanceInvocations;
        private int runInTransactionInvocations;
        private boolean failOnFindByIdWithLock;
        private boolean failOnRunInTransaction;

        void seed(String id, Long userId, String iban, String currency, BigDecimal balance)
        {
            accounts.put(id, new AccountState(id, userId, iban, currency, balance));
        }

        void setFailOnFindByIdWithLock(boolean fail)
        {
            this.failOnFindByIdWithLock = fail;
        }

        void setFailOnRunInTransaction(boolean fail)
        {
            this.failOnRunInTransaction = fail;
        }

        BigDecimal balanceOf(String accountId)
        {
            final AccountState state = accounts.get(accountId);
            return state == null ? null : state.balance;
        }

        int updateBalanceInvocations()
        {
            return updateBalanceInvocations;
        }

        int runInTransactionInvocations()
        {
            return runInTransactionInvocations;
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
            if (failOnFindByIdWithLock)
            {
                throw new CannotAcquireLockException(
                        "simulated database lock timeout on account " + accountId);
            }
            final AccountState state = accounts.get(accountId);
            return state == null ? Optional.empty() : Optional.of(state.toProjection());
        }

        @Override
        public void updateBalance(String accountId, BigDecimal newBalance)
        {
            updateBalanceInvocations++;
            final AccountState state = accounts.get(accountId);
            if (state != null)
            {
                state.balance = newBalance;
            }
        }

        @Override
        public <T> T runInTransaction(Supplier<T> block)
        {
            runInTransactionInvocations++;
            if (failOnRunInTransaction)
            {
                throw new CannotAcquireLockException("simulated database lock timeout inside transaction");
            }
            return block.get();
        }

        private static final class AccountState
        {

            private final String id;
            private final Long userId;
            private final String iban;
            private final String currency;
            private BigDecimal balance;

            AccountState(String id, Long userId, String iban, String currency, BigDecimal balance)
            {
                this.id = id;
                this.userId = userId;
                this.iban = iban;
                this.currency = currency;
                this.balance = balance;
            }

            AccountProjection toProjection()
            {
                return new AccountProjection(id, userId, iban, currency, balance);
            }
        }
    }
}
