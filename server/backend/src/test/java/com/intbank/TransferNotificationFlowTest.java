package com.intbank;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.ProcessTransferUseCase;
import com.intbank.core.domain.entity.Account;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.Iban;
import com.intbank.core.domain.vo.Money;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.service.NotificationService;
import com.intbank.service.OutboxProcessorService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TransferNotificationFlowTest
{

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

    @Mock
    private KafkaTemplate<String, String> kafkaTemplate;

    private ObjectMapper objectMapper;
    private ProcessTransferUseCase processTransferUseCase;

    @BeforeEach
    void setUp()
    {
        objectMapper = new ObjectMapper().findAndRegisterModules();
        processTransferUseCase = new ProcessTransferUseCase(
                accountRepository,
                transferRepository,
                ledgerRepository,
                outboxRepo,
                objectMapper,
                notificationService,
                null
        );
    }

    @Test
    void testProcessTransfer_SendsNotificationsToBothSenderAndReceiver()
    {
        when(transferRepository.findById("tx-notif-1")).thenReturn(Optional.empty());

        AccountRepository.AccountProjection sender = new AccountRepository.AccountProjection("10", 100L, "RO49INTB0000000000000010", "RON", BigDecimal.valueOf(1000));
        AccountRepository.AccountProjection receiver = new AccountRepository.AccountProjection("20", 200L, "RO49INTB0000000000000020", "RON", BigDecimal.valueOf(250));

        doAnswer(invocation -> ((java.util.function.Supplier<?>) invocation.getArgument(0)).get())
                .when(accountRepository).runInTransaction(any());

        when(accountRepository.findByIdWithLock("10")).thenReturn(Optional.of(sender));
        when(accountRepository.findByIdWithLock("20")).thenReturn(Optional.of(receiver));

        TransferInitiatedEvent event = new TransferInitiatedEvent(
                "tx-notif-1",
                "10",
                "20",
                "RO49INTB0000000000000010",
                "RO49INTB0000000000000020",
                BigDecimal.valueOf(150),
                "RON",
                "Plata chirie",
                Instant.now()
        );

        processTransferUseCase.execute(event);

        // Verify balances updated
        verify(accountRepository).updateBalance("10", BigDecimal.valueOf(850).setScale(2));
        verify(accountRepository).updateBalance("20", BigDecimal.valueOf(400).setScale(2));

        // Verify notification for receiver (user 200L)
        verify(notificationService).notify(
                eq(200L),
                eq("Bani primi\u021bi: +150 RON"),
                contains("RO49INTB0000000000000010"),
                eq("TRANSFER_RECEIVED")
        );

        // Verify notification for sender (user 100L)
        verify(notificationService).notify(
                eq(100L),
                eq("Transfer trimis: -150 RON"),
                contains("RO49INTB0000000000000020"),
                eq("TRANSFER_SENT")
        );
    }

    @Test
    void testOutboxProcessor_FallsBackToLocalDeliveryWhenKafkaFails() throws Exception
    {
        OutboxProcessorService outboxService = new OutboxProcessorService(
                outboxRepo, kafkaTemplate, processTransferUseCase, objectMapper, true
        );

        TransferInitiatedEvent event = new TransferInitiatedEvent(
                "tx-fallback-1",
                "1",
                "2",
                "RO49INTB0000000000000001",
                "RO49INTB0000000000000002",
                BigDecimal.valueOf(50),
                "RON",
                "Test fallback",
                Instant.now()
        );

        OutboxJpaEntity outboxEntity = new OutboxJpaEntity();
        outboxEntity.setId(99L);
        outboxEntity.setTopic(TransferInitiatedEvent.EVENT_NAME);
        outboxEntity.setPartitionKey("1");
        outboxEntity.setPayload(objectMapper.writeValueAsString(event));
        outboxEntity.setStatus("PENDING");

        when(outboxRepo.findTop100ByStatusAndRetryCountLessThanOrderByCreatedAtAsc("PENDING", 5))
                .thenReturn(List.of(outboxEntity));

        // Kafka fails with exception (broker offline)
        CompletableFuture failedFuture = new CompletableFuture<>();
        failedFuture.completeExceptionally(new RuntimeException("Connection refused: broker offline"));
        when(kafkaTemplate.send(anyString(), anyString(), anyString())).thenReturn(failedFuture);

        // Mock accounts for local delivery
        AccountRepository.AccountProjection sender = new AccountRepository.AccountProjection("1", 1L, "RO49INTB0000000000000001", "RON", BigDecimal.valueOf(500));
        AccountRepository.AccountProjection receiver = new AccountRepository.AccountProjection("2", 2L, "RO49INTB0000000000000002", "RON", BigDecimal.valueOf(100));

        doAnswer(invocation -> ((java.util.function.Supplier<?>) invocation.getArgument(0)).get())
                .when(accountRepository).runInTransaction(any());

        when(accountRepository.findByIdWithLock("1")).thenReturn(Optional.of(sender));
        when(accountRepository.findByIdWithLock("2")).thenReturn(Optional.of(receiver));

        outboxService.processOutbox();

        // Verify outbox was marked SENT through local delivery fallback
        assertEquals("SENT", outboxEntity.getStatus());
        verify(outboxRepo).save(outboxEntity);

        // Verify notifications were delivered despite Kafka broker being down
        verify(notificationService).notify(eq(2L), anyString(), anyString(), eq("TRANSFER_RECEIVED"));
        verify(notificationService).notify(eq(1L), anyString(), anyString(), eq("TRANSFER_SENT"));
    }
}
