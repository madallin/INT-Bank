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
export class ProcessTransferUseCase
{
  private readonly logger = new Logger(ProcessTransferUseCase.name);

  constructor(
    private readonly accountRepository: AccountRepository,
    private readonly transferRepository: TransferRepository,
    private readonly eventPublisher: EventPublisher,
  ) {}

  async execute(event: TransferInitiatedEvent): Promise<void>
  {
    const { transferId, fromAccountId, toAccountId, amount, currency, reason } =
      event;

    this.logger.log(
      `Processing transfer [${transferId}]: ${fromAccountId} -> ${toAccountId} | ${amount} ${currency}`,
    );

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

    // Simulated 2s payment processing delay
    await this.delay(2000);

    try
    {
      await this.processInTransaction(transferId, fromAccountId, toAccountId, amount, currency);

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
    }
    catch (error)
    {
      const errMsg =
        error instanceof Error ? error.message : 'Unknown processing error';

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

  // Real implementation would use TypeORM EntityManager.transaction()
  // with pessimistic_write locks on sender/receiver rows
  // (see AccountRepository.findByIdWithLock).
  private async processInTransaction(
    transferId: string,
    fromAccountId: number,
    toAccountId: number,
    amount: number,
    currency: string,
  ): Promise<void>
  {
    const sender = await this.accountRepository.findByIdWithLock(fromAccountId);
    const receiver = await this.accountRepository.findByIdWithLock(toAccountId);

    if(!sender)
    {
      throw new Error(`Sender account ${fromAccountId} not found (transfer ${transferId})`);
    }
    if(!receiver)
    {
      throw new Error(`Receiver account ${toAccountId} not found (transfer ${transferId})`);
    }

    if(sender.moneda !== currency)
    {
      throw new Error(
        `Sender currency mismatch: account is ${sender.moneda}, transfer is ${currency}`,
      );
    }

    const senderSold = Number(sender.sold);
    if(senderSold < amount)
    {
      throw new Error(
        `Insufficient funds: balance ${senderSold} ${currency}, required ${amount} ${currency}`,
      );
    }

    const newSenderBalance = parseFloat((senderSold - amount).toFixed(2));
    const newReceiverBalance = parseFloat(
      (Number(receiver.sold) + amount).toFixed(2),
    );

    await this.accountRepository.updateBalance(fromAccountId, newSenderBalance);
    await this.accountRepository.updateBalance(toAccountId, newReceiverBalance);
  }

  private delay(ms: number): Promise<void>
  {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
