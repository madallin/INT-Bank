// ============================================================
// Process Transfer Use Case
// Hexagonal Architecture — Application Layer
// Called by the Kafka Consumer adapter when a transfer.initiated
// event is received. Simulates payment processing with a mock
// 2-second delay, then updates balances inside an ACID transaction.
// Emits transfer.completed or transfer.failed events.
// ============================================================

import { Injectable, Logger } from '@nestjs/common';

import { AccountRepository } from '../../core/ports/out/account.repository.interface';
import { TransferRepository } from '../../core/ports/out/transfer.repository.interface';
import { EventPublisher } from '../../core/ports/out/event-publisher.interface';
import { TransferStatus } from '../../core/domain/transfer.entity';
import type {
  Transfer,
  TransferInitiatedEvent,
  TransferCompletedEvent,
  TransferFailedEvent,
} from '../../core/domain/transfer.entity';

@Injectable()
export class ProcessTransferUseCase {
  private readonly logger = new Logger(ProcessTransferUseCase.name);

  constructor(
    private readonly accountRepository: AccountRepository,
    private readonly transferRepository: TransferRepository,
    private readonly eventPublisher: EventPublisher,
  ) {}

  async execute(event: TransferInitiatedEvent): Promise<void> {
    const { transferId, fromAccountId, toAccountId, amount, currency, reason } =
      event;

    this.logger.log(
      `Processing transfer [${transferId}]: ${fromAccountId} → ${toAccountId} | ${amount} ${currency}`,
    );

    // 1. Create a transfer record (status = PROCESSING)
    const transferRecord: Transfer = {
      id: transferId,
      fromAccountId,
      toAccountId,
      amount,
      currency,
      reason,
      status: TransferStatus.PROCESSING,
      initiatedAt: new Date(event.initiatedAt),
    };

    await this.transferRepository.save(transferRecord);

    // 2. Simulate payment processing delay (~2 seconds)
    await this.delay(2000);

    // 3. Process inside an ACID transaction
    try {
      // Simulated EntityManager: in real-world TypeORM, you'd use
      // `@InjectEntityManager() private readonly em: EntityManager`
      // and wrap everything in `await this.em.transaction(async (txn) => { ... })`.
      // For this portfolio scaffold, we demonstrate the pattern without
      // requiring a running PostgreSQL instance at build time.
      await this.processInTransaction(transferId, fromAccountId, toAccountId, amount, currency);

      // 4. Emit transfer.completed
      const completedEvent: TransferCompletedEvent = {
        eventType: 'transfer.completed',
        transferId,
        fromAccountId,
        toAccountId,
        amount,
        currency,
        completedAt: new Date().toISOString(),
      };

      await this.eventPublisher.publish(
        'transfer.completed',
        transferId,
        completedEvent as unknown as Record<string, unknown>,
      );

      await this.transferRepository.updateStatus(
        transferId,
        TransferStatus.COMPLETED,
        new Date(),
      );

      this.logger.log(`Transfer [${transferId}] completed successfully`);
    } catch (error) {
      const errMsg =
        error instanceof Error ? error.message : 'Unknown processing error';

      // 5. Emit transfer.failed
      const failedEvent: TransferFailedEvent = {
        eventType: 'transfer.failed',
        transferId,
        fromAccountId,
        toAccountId,
        amount,
        currency,
        failureReason: errMsg,
        failedAt: new Date().toISOString(),
      };

      await this.eventPublisher.publish(
        'transfer.failed',
        transferId,
        failedEvent as unknown as Record<string, unknown>,
      );

      await this.transferRepository.updateStatus(
        transferId,
        TransferStatus.FAILED,
        undefined,
        errMsg,
      );

      this.logger.error(
        `Transfer [${transferId}] failed: ${errMsg}`,
      );
    }
  }

  /**
   * Simulated ACID transaction using pessimistic locking.
   *
   * Real implementation using TypeORM EntityManager:
   *
   *   await this.entityManager.transaction(async (txn) => {
   *     const sender = await txn.findOne(AccountOrmEntity, {
   *       where: { id: fromAccountId },
   *       lock: { mode: 'pessimistic_write' },
   *     });
   *     const receiver = await txn.findOne(AccountOrmEntity, {
   *       where: { id: toAccountId },
   *       lock: { mode: 'pessimistic_write' },
   *     });
   *
   *     if (!sender || !receiver) throw new Error('Account not found');
   *     if (sender.sold < amount) throw new Error('Insufficient funds');
   *
   *     sender.sold -= amount;
   *     receiver.sold += amount;
   *
   *     await txn.save(sender);
   *     await txn.save(receiver);
   *   });
   */
  private async processInTransaction(
    transferId: string,
    fromAccountId: number,
    toAccountId: number,
    amount: number,
    currency: string,
  ): Promise<void> {
    // Fetch with lock (simulated)
    const sender = await this.accountRepository.findByIdWithLock(fromAccountId);
    const receiver = await this.accountRepository.findByIdWithLock(toAccountId);

    if (!sender) {
      throw new Error(`Sender account ${fromAccountId} not found (transfer ${transferId})`);
    }
    if (!receiver) {
      throw new Error(`Receiver account ${toAccountId} not found (transfer ${transferId})`);
    }

    // Verify currency compatibility
    if (sender.moneda !== currency) {
      throw new Error(
        `Sender currency mismatch: account is ${sender.moneda}, transfer is ${currency}`,
      );
    }

    // Check sufficient funds
    const senderSold = Number(sender.sold);
    if (senderSold < amount) {
      throw new Error(
        `Insufficient funds: balance ${senderSold} ${currency}, required ${amount} ${currency}`,
      );
    }

    const newSenderBalance = parseFloat((senderSold - amount).toFixed(2));
    const newReceiverBalance = parseFloat(
      (Number(receiver.sold) + amount).toFixed(2),
    );

    // Update balances (inside a real transaction these would share an EntityManager)
    await this.accountRepository.updateBalance(fromAccountId, newSenderBalance);
    await this.accountRepository.updateBalance(toAccountId, newReceiverBalance);
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
