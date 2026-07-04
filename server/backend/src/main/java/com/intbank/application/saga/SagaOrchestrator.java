package com.intbank.application.saga;

import com.intbank.core.domain.event.TransferCompletedEvent;
import com.intbank.core.domain.event.TransferFailedEvent;
import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.service.RetryService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class SagaOrchestrator
{

    private static final Logger log = LoggerFactory.getLogger(SagaOrchestrator.class);

    private final AccountRepository accountRepository;
    private final TransferRepository transferRepository;
    private final EventPublisher eventPublisher;
    private final RetryService retryService;
    private final Map<String, SagaState> sagaStates = new ConcurrentHashMap<>();

    public SagaOrchestrator(AccountRepository accountRepository, TransferRepository transferRepository,
                             EventPublisher eventPublisher, RetryService retryService)
    {
        this.accountRepository = accountRepository;
        this.transferRepository = transferRepository;
        this.eventPublisher = eventPublisher;
        this.retryService = retryService;
    }

    public void execute(TransferInitiatedEvent event, List<SagaStep> steps)
    {
        String transferId = event.trackingId();
        sagaStates.put(transferId, SagaState.IN_PROGRESS);

        SagaContext context = new SagaContext(
                transferId, event.fromAccountId(), event.toAccountId(),
                event.amount(), event.currency(), event.description(), new HashMap<>());

        List<Integer> executedSteps = new ArrayList<>();
        boolean sagaFailed = false;
        String failureReason = "";

        try
        {
            accountRepository.runInTransaction(() ->
            {
                for (int i = 0; i < steps.size(); i++)
                {
                    SagaStep step = steps.get(i);
                    try
                    {
                        log.info("Saga [{}] step {}/{}: {}", transferId, i + 1, steps.size(), step.name());
                        step.execute().execute(context);
                        executedSteps.add(i);
                    }
                    catch (Exception error)
                    {
                        String errMsg = error.getMessage() != null ? error.getMessage() : "Unknown error";
                        log.error("Saga [{}] step {} failed: {}", transferId, step.name(), errMsg);

                        if (step.isCritical())
                        {
                            log.warn("Saga [{}] critical step {} failed — pushing forward", transferId, step.name());
                            executedSteps.add(i);
                            continue;
                        }
                        throw new RuntimeException(errMsg);
                    }
                }
                return null;
            });
        }
        catch (Exception e)
        {
            sagaFailed = true;
            failureReason = e.getMessage() != null ? e.getMessage() : "Saga execution failed";
        }

        if (sagaFailed)
        {
            sagaStates.put(transferId, SagaState.COMPENSATING);
            log.warn("Saga [{}] compensating {} steps in reverse", transferId, executedSteps.size());
            compensate(context, steps, executedSteps, failureReason);
            return;
        }

        publishSuccessEvents(context);
        sagaStates.put(transferId, SagaState.COMPLETED);
        log.info("Saga [{}] completed successfully", transferId);
    }

    private void compensate(SagaContext context, List<SagaStep> steps, List<Integer> executedSteps, String failureReason)
    {
        var reversed = new ArrayList<>(executedSteps);
        Collections.reverse(reversed);
        int compensationErrors = 0;

        for (int stepIndex : reversed)
        {
            SagaStep step = steps.get(stepIndex);
            try
            {
                retryService.execute(() ->
                {
                    step.compensate().compensate(context);
                    return null;
                }, new RetryService.RetryOptions(3, 500, 30000, RetryService.BackoffStrategy.EXPONENTIAL, null));
                log.info("Saga [{}] compensated step: {}", context.transferId(), step.name());
            }
            catch (Exception err)
            {
                compensationErrors++;
                log.error("Saga [{}] compensation failed for step: {}", context.transferId(), step.name(), err);
            }
        }

        transferRepository.updateStatus(context.transferId(), TransferStatus.FAILED, null);

        SagaState finalState = compensationErrors == 0 ? SagaState.COMPENSATED : SagaState.FAILED;
        sagaStates.put(context.transferId(), finalState);

        String finalReason = compensationErrors > 0
                ? failureReason + " (compensation had " + compensationErrors + " errors)"
                : failureReason;

        TransferFailedEvent failedEvent = new TransferFailedEvent(
                context.transferId(), context.fromAccountId(), context.toAccountId(),
                "", "", context.amount(), context.currency(), finalReason, Instant.now());

        Map<String, Object> eventMap = new LinkedHashMap<>();
        eventMap.put("trackingId", failedEvent.trackingId());
        eventMap.put("fromAccountId", failedEvent.fromAccountId());
        eventMap.put("toAccountId", failedEvent.toAccountId());
        eventMap.put("amount", failedEvent.amount());
        eventMap.put("currency", failedEvent.currency());
        eventMap.put("failureReason", failedEvent.failureReason());
        eventMap.put("failedAt", failedEvent.failedAt().toString());

        eventPublisher.publish(TransferFailedEvent.EVENT_NAME, context.transferId(), eventMap);
    }

    public List<SagaStep> buildTransferSagaSteps()
    {
        return List.of(
                new SagaStep("RESERVE_FUNDS",
                        ctx ->
                        {
                            var sender = accountRepository.findByIdWithLock(ctx.fromAccountId())
                                    .orElseThrow(() -> new RuntimeException("Sender account " + ctx.fromAccountId() + " not found"));
                            if (!sender.moneda().equals(ctx.currency()))
                            {
                                throw new RuntimeException("Currency mismatch: " + sender.moneda() + " vs " + ctx.currency());
                            }
                            if (sender.sold() < ctx.amount())
                            {
                                throw new RuntimeException("Insufficient funds: " + sender.sold() + " < " + ctx.amount());
                            }
                            double newBalance = Math.round((sender.sold() - ctx.amount()) * 100.0) / 100.0;
                            accountRepository.updateBalance(ctx.fromAccountId(), newBalance);
                            ctx.metadata().put("previousSenderBalance", sender.sold());
                        },
                        ctx ->
                        {
                            double previousBalance = (Double) ctx.metadata().get("previousSenderBalance");
                            accountRepository.updateBalance(ctx.fromAccountId(), previousBalance);
                        },
                        false
                ),
                new SagaStep("CREDIT_RECEIVER",
                        ctx ->
                        {
                            var receiver = accountRepository.findByIdWithLock(ctx.toAccountId())
                                    .orElseThrow(() -> new RuntimeException("Receiver account " + ctx.toAccountId() + " not found"));
                            double newBalance = Math.round((receiver.sold() + ctx.amount()) * 100.0) / 100.0;
                            accountRepository.updateBalance(ctx.toAccountId(), newBalance);
                            ctx.metadata().put("previousReceiverBalance", receiver.sold());
                        },
                        ctx ->
                        {
                            double previousBalance = (Double) ctx.metadata().get("previousReceiverBalance");
                            accountRepository.updateBalance(ctx.toAccountId(), previousBalance);
                        },
                        false
                ),
                new SagaStep("RECORD_TRANSFER",
                        ctx ->
                        {
                            transferRepository.updateStatusWithEntity(ctx.transferId(), TransferStatus.COMPLETED, Instant.now(), null);
                        },
                        ctx ->
                        {
                        },
                        true
                )
        );
    }

    private void publishSuccessEvents(SagaContext context)
    {
        TransferCompletedEvent completedEvent = new TransferCompletedEvent(
                context.transferId(), context.fromAccountId(), context.toAccountId(),
                "", "", context.amount(), context.currency(), Instant.now());

        Map<String, Object> eventMap = new LinkedHashMap<>();
        eventMap.put("trackingId", completedEvent.trackingId());
        eventMap.put("fromAccountId", completedEvent.fromAccountId());
        eventMap.put("toAccountId", completedEvent.toAccountId());
        eventMap.put("amount", completedEvent.amount());
        eventMap.put("currency", completedEvent.currency());
        eventMap.put("completedAt", completedEvent.completedAt().toString());

        eventPublisher.publish(TransferCompletedEvent.EVENT_NAME, context.transferId(), eventMap);
    }

    public SagaState getSagaState(String transferId)
    {
        return sagaStates.getOrDefault(transferId, SagaState.NOT_STARTED);
    }

    public enum SagaState
    {
        NOT_STARTED, IN_PROGRESS, COMPLETED, COMPENSATING, COMPENSATED, FAILED
    }

    public record SagaStep(String name, SagaStepExecutor execute, SagaStepCompensator compensate, boolean isCritical)
    {
        public interface SagaStepExecutor
        {
            void execute(SagaContext ctx) throws Exception;
        }

        public interface SagaStepCompensator
        {
            void compensate(SagaContext ctx) throws Exception;
        }
    }

    public record SagaContext(String transferId, String fromAccountId, String toAccountId, double amount,
                               String currency, String reason, Map<String, Object> metadata)
    {
    }
}