package com.intbank.application.usecase;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.infrastructure.security.AuthenticatedClient;
import com.intbank.service.IdempotencyService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
    private final TransferRepository transferRepository;
    private final OutboxJpaRepository outboxRepo;
    private final IdempotencyService idempotencyService;
    private final ObjectMapper objectMapper;
    private final com.intbank.service.AmlVelocityService amlVelocityService;
    private final com.intbank.service.AuditLogService auditLogService;
    private final com.intbank.service.RedlockDistributedLockService distributedLockService;
    private TransferInitiatedEvent lastPublishedEvent;

    public InitiateTransferUseCase(EventPublisher eventPublisher, AccountRepository accountRepository,
                                   TransferRepository transferRepository, OutboxJpaRepository outboxRepo,
                                   IdempotencyService idempotencyService, ObjectMapper objectMapper,
                                   com.intbank.service.AmlVelocityService amlVelocityService,
                                   com.intbank.service.AuditLogService auditLogService)
    {
        this(eventPublisher, accountRepository, transferRepository, outboxRepo,
                idempotencyService, objectMapper, amlVelocityService, auditLogService, null);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public InitiateTransferUseCase(EventPublisher eventPublisher, AccountRepository accountRepository,
                                   TransferRepository transferRepository, OutboxJpaRepository outboxRepo,
                                   IdempotencyService idempotencyService, ObjectMapper objectMapper,
                                   com.intbank.service.AmlVelocityService amlVelocityService,
                                   com.intbank.service.AuditLogService auditLogService,
                                   @org.springframework.beans.factory.annotation.Autowired(required = false) com.intbank.service.RedlockDistributedLockService distributedLockService)
    {
        this.eventPublisher = eventPublisher;
        this.accountRepository = accountRepository;
        this.transferRepository = transferRepository;
        this.outboxRepo = outboxRepo;
        this.idempotencyService = idempotencyService;
        this.objectMapper = objectMapper;
        this.amlVelocityService = amlVelocityService;
        this.auditLogService = auditLogService;
        this.distributedLockService = distributedLockService;
    }

    @Override
    public InitiateTransferResponse initiate(InitiateTransferRequest request)
    {
        String idempotencyKey = request.idempotencyKey();

        var sourceAccount = accountRepository.findByIban(request.fromIban())
                .orElseThrow(() -> new IllegalArgumentException("Source account " + request.fromIban() + " not found"));

        var destAccount = accountRepository.findByIban(request.toIban())
                .orElseThrow(() -> new IllegalArgumentException("Destination account " + request.toIban() + " not found"));

        verifyOwnership(sourceAccount.userId(), request.fromIban());

        // AML Velocity & Fraud Evaluation
        var amlResult = amlVelocityService.evaluateTransfer(sourceAccount.userId(), request.amount(), request.currency());
        if (amlResult.assessment() == com.intbank.service.AmlVelocityService.RiskAssessment.VELOCITY_LIMIT_EXCEEDED
                || amlResult.assessment() == com.intbank.service.AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED)
        {
            throw new IllegalArgumentException("AML Alert: " + amlResult.message());
        }

        String requestHash = IdempotencyService.hashRequest(
                request.amount(), request.currency(), request.fromIban(), request.toIban(), request.reason());

        IdempotencyService.Decision decision = idempotencyService.beginOrGet(idempotencyKey, sourceAccount.userId(), requestHash);

        return switch (decision.outcome())
        {
            case DUPLICATE_COMPLETED -> rebuildFromCached(decision.cachedResponsePayload(), idempotencyKey);
            case DUPLICATE_IN_PROGRESS -> throw new IllegalStateException(
                    "A transfer with the same Idempotency-Key is already being processed");
            case PROCEED ->
            {
                String lockKey = "account:lock:" + sourceAccount.id();
                boolean locked = false;
                if (distributedLockService != null)
                {
                    locked = distributedLockService.acquireLock(lockKey, 10);
                    if (!locked)
                    {
                        throw new IllegalStateException(
                                "Account " + request.fromIban() + " is currently locked by a concurrent transfer. Please retry.");
                    }
                }
                try
                {
                    yield doInitiate(request, sourceAccount.id(), destAccount.id(), idempotencyKey);
                }
                finally
                {
                    if (distributedLockService != null && locked)
                    {
                        distributedLockService.releaseLock(lockKey);
                    }
                }
            }
        };
    }

    @Transactional
    protected InitiateTransferResponse doInitiate(InitiateTransferRequest request, String fromAccountId,
                                                  String toAccountId, String idempotencyKey)
    {
        try
        {
            if (request.amount().signum() <= 0)
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

            String trackingId = UUID.randomUUID().toString();
            Instant now = Instant.now();
            String currency = request.currency() != null ? request.currency() : "RON";

            TransferInitiatedEvent event = new TransferInitiatedEvent(
                    trackingId,
                    fromAccountId,
                    toAccountId,
                    request.fromIban(),
                    request.toIban(),
                    request.amount(),
                    currency,
                    request.reason(),
                    now
            );

            // Persist the transfer row and the outbox event in the SAME transaction.
            transferRepository.save(new TransferRepository.TransferProjection(
                    trackingId, fromAccountId, toAccountId, request.amount(), currency,
                    request.reason(), TransferStatus.PENDING, now, null, null));
            outboxRepo.save(toOutbox(event));

            this.lastPublishedEvent = event;

            log.info("Initiated transfer [{}] {} -> {} | {} {} (idempotency {})",
                    trackingId, request.fromIban(), request.toIban(), request.amount(), currency, idempotencyKey);

            auditLogService.log(
                    null,
                    "TRANSFER_INITIATED",
                    "Transfer " + trackingId + ": " + request.fromIban() + " -> " + request.toIban() + " | " + request.amount() + " " + currency,
                    "127.0.0.1"
            );

            InitiateTransferResponse response = new InitiateTransferResponse(
                    trackingId,
                    TransferStatus.PENDING,
                    "Transfer initiated. Processing will complete shortly."
            );
            idempotencyService.complete(idempotencyKey, toResponseMap(response));
            return response;
        }
        catch (RuntimeException ex)
        {
            idempotencyService.fail(idempotencyKey, ex.getMessage());
            throw ex;
        }
    }

    private OutboxJpaEntity toOutbox(TransferInitiatedEvent event)
    {
        OutboxJpaEntity outbox = new OutboxJpaEntity();
        outbox.setTopic(TransferInitiatedEvent.EVENT_NAME);
        outbox.setPartitionKey(event.fromAccountId());
        try
        {
            outbox.setPayload(objectMapper.writeValueAsString(toMap(event)));
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Failed to serialize outbox payload", e);
        }
        outbox.setStatus("PENDING");
        return outbox;
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

    private Map<String, Object> toResponseMap(InitiateTransferResponse response)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("trackingId", response.trackingId());
        map.put("status", response.status().name());
        map.put("message", response.message());
        return map;
    }

    @SuppressWarnings("unchecked")
    private InitiateTransferResponse rebuildFromCached(String payload, String idempotencyKey)
    {
        try
        {
            Map<String, Object> map = objectMapper.readValue(payload, Map.class);
            return new InitiateTransferResponse(
                    String.valueOf(map.get("trackingId")),
                    TransferStatus.valueOf(String.valueOf(map.get("status"))),
                    String.valueOf(map.get("message"))
            );
        }
        catch (Exception e)
        {
            log.warn("Could not deserialize cached idempotency response for key {}", idempotencyKey);
            return new InitiateTransferResponse(idempotencyKey, TransferStatus.PENDING,
                    "Transfer already initiated (cached response unavailable)");
        }
    }

    private void verifyOwnership(Long accountUserId, String fromIban)
    {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthenticatedClient client) || client.userId() == null)
        {
            log.warn("Ownership check skipped for {}: no authenticated user context", fromIban);
            return;
        }
        if (!client.userId().equals(accountUserId))
        {
            throw new SecurityException("Account " + fromIban + " does not belong to the authenticated user");
        }
    }

    @Override
    public TransferInitiatedEvent getLastPublishedEvent()
    {
        return lastPublishedEvent;
    }
}
