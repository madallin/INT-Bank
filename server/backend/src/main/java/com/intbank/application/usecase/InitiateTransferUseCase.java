package com.intbank.application.usecase;

import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.EventPublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class InitiateTransferUseCase implements TransferUseCase
{

    private static final Logger log = LoggerFactory.getLogger(InitiateTransferUseCase.class);

    private final EventPublisher eventPublisher;
    private final AccountRepository accountRepository;
    private TransferInitiatedEvent lastPublishedEvent;

    public InitiateTransferUseCase(EventPublisher eventPublisher, AccountRepository accountRepository)
    {
        this.eventPublisher = eventPublisher;
        this.accountRepository = accountRepository;
    }

    @Override
    public InitiateTransferResponse initiate(InitiateTransferRequest request)
    {
        String trackingId = UUID.randomUUID().toString();

        if (request.amount() <= 0)
        {
            throw new IllegalArgumentException("Amount must be greater than 0");
        }
        if (request.fromIban().equals(request.toIban()))
        {
            throw new IllegalArgumentException("Cannot transfer to the same account");
        }
        if (request.reason() == null || request.reason().trim().length() < 3)
        {
            throw new IllegalArgumentException("Reason must be at least 3 characters");
        }

        var sourceAccount = accountRepository.findByIban(request.fromIban())
                .orElseThrow(() -> new IllegalArgumentException("Source account " + request.fromIban() + " not found"));

        var destAccount = accountRepository.findByIban(request.toIban())
                .orElseThrow(() -> new IllegalArgumentException("Destination account " + request.toIban() + " not found"));

        TransferInitiatedEvent event = new TransferInitiatedEvent(
                trackingId,
                sourceAccount.id(),
                destAccount.id(),
                request.fromIban(),
                request.toIban(),
                request.amount(),
                request.currency() != null ? request.currency() : "RON",
                request.reason(),
                Instant.now()
        );

        Map<String, Object> eventMap = toMap(event);
        eventPublisher.publish(TransferInitiatedEvent.EVENT_NAME, sourceAccount.id(), eventMap);

        this.lastPublishedEvent = event;

        log.info("Published transfer.initiated event [{}] {} -> {} | {} {}",
                trackingId, request.fromIban(), request.toIban(), request.amount(), request.currency());

        return new InitiateTransferResponse(
            trackingId,
            TransferStatus.PENDING,
            "Transfer initiated. Processing will complete shortly."
        );
    }

    @Override
    public TransferInitiatedEvent getLastPublishedEvent()
    {
        return lastPublishedEvent;
    }

    private Map<String, Object> toMap(TransferInitiatedEvent event)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("trackingId", event.trackingId());
        map.put("fromAccountId", event.fromAccountId());
        map.put("toAccountId", event.toAccountId());
        map.put("fromIban", event.fromIban());
        map.put("toIban", event.toIban());
        map.put("amount", event.amount());
        map.put("currency", event.currency());
        map.put("description", event.description());
        map.put("timestamp", event.timestamp().toString());
        return map;
    }
}