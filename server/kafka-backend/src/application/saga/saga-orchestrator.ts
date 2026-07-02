import { Injectable, Logger } from '@nestjs/common';
import { EntityManager } from 'typeorm';

import { AccountRepository } from '../../core/ports/out/account.repository.interface';
import { TransferRepository } from '../../core/ports/out/transfer.repository.interface';
import { EventPublisher } from '../../core/ports/out/event-publisher.interface';
import { TransferStatus } from '../../core/domain/transfer.entity';
import { RetryService, BackoffStrategy } from '../../infrastructure/services/retry.service';
import type
{
  TransferInitiatedEvent,
  TransferCompletedEvent,
  TransferFailedEvent,
} from '../../core/domain/transfer.entity';

export interface SagaStep
{
  name: string;
  execute: (context: SagaContext) => Promise<void>;
  compensate: (context: SagaContext) => Promise<void>;
  isCritical?: boolean;
}

export interface SagaContext
{
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  reason: string;
  entityManager: EntityManager;
  metadata: Record<string, unknown>;
}

export enum SagaState
{
  NOT_STARTED = 'NOT_STARTED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  COMPENSATING = 'COMPENSATING',
  COMPENSATED = 'COMPENSATED',
  FAILED = 'FAILED',
}

@Injectable()
export class SagaOrchestrator
{
  private readonly logger = new Logger(SagaOrchestrator.name);
  private readonly sagaStates = new Map<string, SagaState>();

  constructor(
    private readonly accountRepository: AccountRepository,
    private readonly transferRepository: TransferRepository,
    private readonly eventPublisher: EventPublisher,
    private readonly retryService: RetryService,
  ) {}

  async execute(
    event: TransferInitiatedEvent,
    steps: SagaStep[],
  ): Promise<void>
  {
    const { transferId } = event;
    this.sagaStates.set(transferId, SagaState.IN_PROGRESS);

    const context: SagaContext = {
      transferId,
      fromAccountId: event.fromAccountId,
      toAccountId: event.toAccountId,
      amount: event.amount,
      currency: event.currency,
      reason: event.reason,
      entityManager: null as unknown as EntityManager,
      metadata: {},
    };

    const executedSteps: number[] = [];
    let sagaFailed = false;
    let failureReason = '';

    // ---- FORWARD EXECUTION ----
    await this.accountRepository.runInTransaction(
      async (entityManager: EntityManager) =>
      {
        context.entityManager = entityManager;

        for(let i = 0; i < steps.length; i++)
        {
          const step = steps[i];

          try
          {
            this.logger.log(
              `Saga [${transferId}] step ${i + 1}/${steps.length}: ${step.name}`,
            );

            await step.execute(context);
            executedSteps.push(i);
          }
          catch(error)
          {
            const errMsg = error instanceof Error ? error.message : 'Unknown error';
            this.logger.error(`Saga [${transferId}] step ${step.name} failed: ${errMsg}`);

            sagaFailed = true;
            failureReason = `Step "${step.name}" failed: ${errMsg}`;

            // Critical steps are points of no return — continue forward instead of compensating
            if(step.isCritical)
            {
              this.logger.warn(
                `Saga [${transferId}] critical step ${step.name} failed — pushing forward`,
              );
              sagaFailed = false;
              executedSteps.push(i);
              continue;
            }

            throw error;
          }
        }

        if(sagaFailed)
        {
          throw new Error(failureReason);
        }
      },
    );

    // ---- COMPENSATION ----
    if(sagaFailed)
    {
      this.sagaStates.set(transferId, SagaState.COMPENSATING);
      this.logger.warn(
        `Saga [${transferId}] compensating ${executedSteps.length} steps in reverse`,
      );

      await this.compensate(context, steps, executedSteps, failureReason);
      return;
    }

    await this.publishSuccessEvents(context);
    this.sagaStates.set(transferId, SagaState.COMPLETED);
    this.logger.log(`Saga [${transferId}] completed successfully`);
  }

  private async compensate(
    context: SagaContext,
    steps: SagaStep[],
    executedSteps: number[],
    failureReason: string,
  ): Promise<void>
  {
    const reversed = [...executedSteps].reverse();
    let compensationErrors = 0;

    for(const stepIndex of reversed)
    {
      const step = steps[stepIndex];

      try
      {
        await this.retryService.execute(
          () => step.compensate(context),
          {
            maxAttempts: 3,
            baseDelayMs: 500,
            strategy: BackoffStrategy.EXPONENTIAL,
          },
        );

        this.logger.log(`Saga [${context.transferId}] compensated step: ${step.name}`);
      }
      catch(err)
      {
        compensationErrors++;
        this.logger.error(
          { err },
          `Saga [${context.transferId}] compensation failed for step: ${step.name}`,
        );
      }
    }

    await this.transferRepository.updateStatus(
      context.transferId,
      TransferStatus.FAILED,
      undefined,
      failureReason,
    );

    const sagaState = compensationErrors === 0
      ? SagaState.COMPENSATED
      : SagaState.FAILED;
    this.sagaStates.set(context.transferId, sagaState);

    const failedEvent: TransferFailedEvent = {
      eventType: 'transfer.failed',
      transferId: context.transferId,
      fromAccountId: context.fromAccountId,
      toAccountId: context.toAccountId,
      amount: context.amount,
      currency: context.currency,
      failureReason: compensationErrors > 0
        ? `${failureReason} (compensation had ${compensationErrors} errors)`
        : failureReason,
      failedAt: new Date().toISOString(),
    };

    await this.eventPublisher.publish(
      'transfer.failed',
      context.transferId,
      failedEvent as unknown as Record<string, unknown>,
    );
  }

  buildTransferSagaSteps(): SagaStep[]
  {
    return [
      {
        name: 'RESERVE_FUNDS',
        execute: async (ctx: SagaContext) =>
        {
          const sender = await this.accountRepository.findByIdWithLock(
            ctx.fromAccountId,
            ctx.entityManager,
          );

          if(!sender)
          {
            throw new Error(`Sender account ${ctx.fromAccountId} not found`);
          }

          if(sender.moneda !== ctx.currency)
          {
            throw new Error(`Currency mismatch: ${sender.moneda} vs ${ctx.currency}`);
          }

          const balance = Number(sender.sold);
          if(balance < ctx.amount)
          {
            throw new Error(`Insufficient funds: ${balance} < ${ctx.amount}`);
          }

          const newBalance = parseFloat((balance - ctx.amount).toFixed(2));
          await this.accountRepository.updateBalance(
            ctx.fromAccountId,
            newBalance,
            ctx.entityManager,
          );

          ctx.metadata.previousSenderBalance = balance;
        },
        compensate: async (ctx: SagaContext) =>
        {
          const previousBalance = ctx.metadata.previousSenderBalance as number;
          await this.accountRepository.updateBalance(
            ctx.fromAccountId,
            previousBalance,
          );
        },
      },
      {
        name: 'CREDIT_RECEIVER',
        execute: async (ctx: SagaContext) =>
        {
          const receiver = await this.accountRepository.findByIdWithLock(
            ctx.toAccountId,
            ctx.entityManager,
          );

          if(!receiver)
          {
            throw new Error(`Receiver account ${ctx.toAccountId} not found`);
          }

          const newBalance = parseFloat(
            (Number(receiver.sold) + ctx.amount).toFixed(2),
          );

          await this.accountRepository.updateBalance(
            ctx.toAccountId,
            newBalance,
            ctx.entityManager,
          );

          ctx.metadata.previousReceiverBalance = Number(receiver.sold);
        },
        compensate: async (ctx: SagaContext) =>
        {
          const previousBalance = ctx.metadata.previousReceiverBalance as number;
          await this.accountRepository.updateBalance(
            ctx.toAccountId,
            previousBalance,
          );
        },
      },
      {
        name: 'RECORD_TRANSFER',
        isCritical: true,
        execute: async (ctx: SagaContext) =>
        {
          await this.transferRepository.updateStatus(
            ctx.transferId,
            TransferStatus.COMPLETED,
            new Date(),
          );
        },
        compensate: async () => {},
      },
    ];
  }

  private async publishSuccessEvents(context: SagaContext): Promise<void>
  {
    const completedEvent: TransferCompletedEvent = {
      eventType: 'transfer.completed',
      transferId: context.transferId,
      fromAccountId: context.fromAccountId,
      toAccountId: context.toAccountId,
      amount: context.amount,
      currency: context.currency,
      completedAt: new Date().toISOString(),
    };

    await this.eventPublisher.publish(
      'transfer.completed',
      context.transferId,
      completedEvent as unknown as Record<string, unknown>,
    );
  }

  getSagaState(transferId: string): SagaState
  {
    return this.sagaStates.get(transferId) ?? SagaState.NOT_STARTED;
  }
}