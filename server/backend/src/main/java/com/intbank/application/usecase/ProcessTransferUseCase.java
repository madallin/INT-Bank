package com.intbank.application.usecase;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.core.domain.event.TransferCompletedEvent;
import com.intbank.core.domain.event.TransferFailedEvent;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class ProcessTransferUseCase
{

    private static final Logger log = LoggerFactory.getLogger(ProcessTransferUseCase.class);

    private final AccountRepository accountRepository;
    private final TransferRepository transferRepository;
    private final LedgerRepository ledgerRepository;
    private final OutboxJpaRepository outboxRepo;
    private final ObjectMapper objectMapper;

    public ProcessTransferUseCase(AccountRepository accountRepository,
                                  TransferRepository transferRepository,
                                  LedgerRepository ledgerRepository,
                                  OutboxJpaRepository outboxRepo,
                                  ObjectMapper objectMapper)
    {
        this.accountRepository = accountRepository;
        this.transferRepository = transferRepository;
        this.ledgerRepository = ledgerRepository;
        this.outboxRepo = outboxRepo;
        this.objectMapper = objectMapper;
    }

    public void execute(TransferInitiatedEvent event)
    {
        String transferId = event.trackingId();
        String fromAccountId = event.fromAccountId();
        String toAccountId = event.toAccountId();
        BigDecimal amount = event.amount();
        String currency = event.currency();
        String reason = event.description();

        log.info("Processing transfer [{}]: {} -> {} | {} {}", transferId, fromAccountId, toAccountId, amount, currency);

        var existingTransfer = transferRepository.findById(transferId);
        if (existingTransfer.isPresent())
        {
            var t = existingTransfer.get();
            if (t.status().isTerminal())
            {
                log.warn("Transfer [{}] already in terminal state: {}. Skipping.", transferId, t.status());
                return;
            }
            log.warn("Transfer [{}] exists with status {}. Will retry processing.", transferId, t.status());
        }

        transferRepository.save(new TransferRepository.TransferProjection(
                transferId, fromAccountId, toAccountId, amount, currency,
                reason, TransferStatus.PENDING, event.timestamp(), null, null));

        try
        {
            Thread.sleep(2000); // Simulated 2s payment processing delay
        }
        catch (InterruptedException e)
        {
            Thread.currentThread().interrupt();
        }

        try
        {
            accountRepository.runInTransaction(() ->
            {
                var sender = accountRepository.findByIdWithLock(fromAccountId)
                        .orElseThrow(() -> new IllegalStateException(
                                "Sender account " + fromAccountId + " not found (transfer " + transferId + ")"));

                var receiver = accountRepository.findByIdWithLock(toAccountId)
                        .orElseThrow(() -> new IllegalStateException(
                                "Receiver account " + toAccountId + " not found (transfer " + transferId + ")"));

                if (!sender.moneda().equals(currency))
                {
                    throw new IllegalStateException(
                            "Sender currency mismatch: account is " + sender.moneda() + ", transfer is " + currency);
                }

                if (sender.sold().compareTo(amount) < 0)
                {
                    throw new IllegalStateException(
                            "Insufficient funds: balance " + sender.sold() + " " + currency
                                    + ", required " + amount + " " + currency);
                }

                BigDecimal newSenderBalance = sender.sold().subtract(amount).setScale(2, RoundingMode.HALF_EVEN);
                BigDecimal newReceiverBalance = receiver.sold().add(amount).setScale(2, RoundingMode.HALF_EVEN);

                accountRepository.updateBalance(fromAccountId, newSenderBalance);
                accountRepository.updateBalance(toAccountId, newReceiverBalance);

                // Double-entry ledger: immutable debit + credit postings.
                ledgerRepository.postEntry(transferId, Long.parseLong(fromAccountId), "DEBIT", amount, currency);
                ledgerRepository.postEntry(transferId, Long.parseLong(toAccountId), "CREDIT", amount, currency);

                transferRepository.updateStatusWithEntity(transferId, TransferStatus.COMPLETED, Instant.now(), null);

                // Completion event persisted to outbox in the same transaction.
                outboxRepo.save(toOutbox(new TransferCompletedEvent(
                        transferId, fromAccountId, toAccountId,
                        event.fromIban(), event.toIban(), amount, currency, Instant.now())));

                log.info("Transfer [{}] funds moved: {} (-{}) {} (+{})",
                        transferId, fromAccountId, amount, toAccountId, amount);
                return null;
            });
        }
        catch (Exception error)
        {
            String errMsg = error.getMessage() != null ? error.getMessage() : "Unknown processing error";
            log.error("Transfer [{}] failed: {}", transferId, errMsg, error);
            markFailed(transferId, fromAccountId, toAccountId, event, errMsg);
        }
    }

    @Transactional
    protected void markFailed(String transferId, String fromAccountId, String toAccountId,
                              TransferInitiatedEvent event, String errMsg)
    {
        transferRepository.updateStatus(transferId, TransferStatus.FAILED, Instant.now());
        outboxRepo.save(toOutbox(new TransferFailedEvent(
                transferId, fromAccountId, toAccountId,
                event.fromIban(), event.toIban(), event.amount(), event.currency(), errMsg, Instant.now())));
    }

    private OutboxJpaEntity toOutbox(TransferCompletedEvent event)
    {
        OutboxJpaEntity outbox = new OutboxJpaEntity();
        outbox.setTopic(TransferCompletedEvent.EVENT_NAME);
        outbox.setPartitionKey(event.trackingId());
        outbox.setPayload(serialize(toMap(event)));
        outbox.setStatus("PENDING");
        return outbox;
    }

    private OutboxJpaEntity toOutbox(TransferFailedEvent event)
    {
        OutboxJpaEntity outbox = new OutboxJpaEntity();
        outbox.setTopic(TransferFailedEvent.EVENT_NAME);
        outbox.setPartitionKey(event.trackingId());
        outbox.setPayload(serialize(toMap(event)));
        outbox.setStatus("PENDING");
        return outbox;
    }

    private String serialize(Map<String, Object> map)
    {
        try
        {
            return objectMapper.writeValueAsString(map);
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Failed to serialize outbox payload", e);
        }
    }

    private Map<String, Object> toMap(TransferCompletedEvent event)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("trackingId", event.trackingId());
        map.put("fromAccountId", event.fromAccountId());
        map.put("toAccountId", event.toAccountId());
        map.put("fromIban", event.fromIban());
        map.put("toIban", event.toIban());
        map.put("amount", event.amount());
        map.put("currency", event.currency());
        map.put("completedAt", event.completedAt().toString());
        return map;
    }

    private Map<String, Object> toMap(TransferFailedEvent event)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("trackingId", event.trackingId());
        map.put("fromAccountId", event.fromAccountId());
        map.put("toAccountId", event.toAccountId());
        map.put("fromIban", event.fromIban());
        map.put("toIban", event.toIban());
        map.put("amount", event.amount());
        map.put("currency", event.currency());
        map.put("failureReason", event.failureReason());
        map.put("failedAt", event.failedAt().toString());
        return map;
    }
}
