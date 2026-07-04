package com.intbank.application.usecase;

import com.intbank.core.domain.event.TransferCompletedEvent;
import com.intbank.core.domain.event.TransferFailedEvent;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.TransferRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class ProcessTransferUseCase
{

    private static final Logger log = LoggerFactory.getLogger(ProcessTransferUseCase.class);

    private final AccountRepository accountRepository;
    private final TransferRepository transferRepository;
    private final EventPublisher eventPublisher;

    public ProcessTransferUseCase(AccountRepository accountRepository,
                                   TransferRepository transferRepository,
                                   EventPublisher eventPublisher)
    {
        this.accountRepository = accountRepository;
        this.transferRepository = transferRepository;
        this.eventPublisher = eventPublisher;
    }

    public void execute(TransferInitiatedEvent event)
    {
        String transferId = event.trackingId();
        String fromAccountId = event.fromAccountId();
        String toAccountId = event.toAccountId();
        double amount = event.amount();
        String currency = event.currency();
        String reason = event.description();

        log.info("Processing transfer [{}]: {} -> {} | {} {}",
                transferId, fromAccountId, toAccountId, amount, currency);

        // IDEMPOTENCY CHECK
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

        // Save initial processing state
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

                if (sender.sold() < amount)
                {
                    throw new IllegalStateException(
                            "Insufficient funds: balance " + sender.sold() + " " + currency
                                    + ", required " + amount + " " + currency);
                }

                double newSenderBalance = Math.round((sender.sold() - amount) * 100.0) / 100.0;
                double newReceiverBalance = Math.round((receiver.sold() + amount) * 100.0) / 100.0;

                accountRepository.updateBalance(fromAccountId, newSenderBalance);
                accountRepository.updateBalance(toAccountId, newReceiverBalance);

                transferRepository.updateStatusWithEntity(transferId, TransferStatus.COMPLETED, Instant.now(), null);

                log.info("Transfer [{}] funds moved: {} (-{}) {} (+{})",
                        transferId, fromAccountId, amount, toAccountId, amount);
                return null;
            });

            // Publish success event
            TransferCompletedEvent completedEvent = new TransferCompletedEvent(
                    transferId, fromAccountId, toAccountId,
                    event.fromIban(), event.toIban(), amount, currency, Instant.now());

            eventPublisher.publish(TransferCompletedEvent.EVENT_NAME, transferId, toMap(completedEvent));
            log.info("Transfer [{}] completed successfully", transferId);

        }
        catch (Exception error)
        {
            String errMsg = error.getMessage() != null ? error.getMessage() : "Unknown processing error";

            transferRepository.updateStatus(transferId, TransferStatus.FAILED, null);

            TransferFailedEvent failedEvent = new TransferFailedEvent(
                    transferId, fromAccountId, toAccountId,
                    event.fromIban(), event.toIban(), amount, currency, errMsg, Instant.now());

            eventPublisher.publish(TransferFailedEvent.EVENT_NAME, transferId, toMap(failedEvent));
            log.error("Transfer [{}] failed: {}", transferId, errMsg, error);
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