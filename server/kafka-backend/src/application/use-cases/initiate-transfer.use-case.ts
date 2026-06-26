import { Injectable, Logger } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';

import {
  TransferUseCase,
  InitiateTransferRequest,
  InitiateTransferResponse,
} from '../../core/ports/in/transfer.use-case';
import { EventPublisher } from '../../core/ports/out/event-publisher.interface';
import { AccountRepository } from '../../core/ports/out/account.repository.interface';
import {
  TransferStatus,
  TransferInitiatedEvent,
} from '../../core/domain/transfer.entity';

@Injectable()
export class InitiateTransferUseCase implements TransferUseCase
{
  private readonly logger = new Logger(InitiateTransferUseCase.name);
  private lastPublishedEvent: TransferInitiatedEvent | null = null;

  constructor(
    private readonly eventPublisher: EventPublisher,
    private readonly accountRepository: AccountRepository,
  ) {}

  async initiate(
    request: InitiateTransferRequest,
  ): Promise<InitiateTransferResponse>
  {
    const trackingId = uuidv4();

    if(request.amount <= 0)
    {
      throw new Error('Amount must be greater than 0');
    }
    if(request.fromIban === request.toIban)
    {
      throw new Error('Cannot transfer to the same account');
    }
    if(!request.reason || request.reason.trim().length < 3)
    {
      throw new Error('Reason must be at least 3 characters');
    }

    const sourceAccount = await this.accountRepository.findByIban(
      request.fromIban,
    );
    if(!sourceAccount)
    {
      throw new Error(`Source account ${request.fromIban} not found`);
    }

    const destAccount = await this.accountRepository.findByIban(
      request.toIban,
    );
    if(!destAccount)
    {
      throw new Error(`Destination account ${request.toIban} not found`);
    }

    const event: TransferInitiatedEvent = {
      eventType: 'transfer.initiated',
      transferId: trackingId,
      fromAccountId: sourceAccount.id,
      toAccountId: destAccount.id,
      amount: request.amount,
      currency: request.currency || 'RON',
      reason: request.reason,
      initiatedAt: new Date().toISOString(),
    };

    await this.eventPublisher.publish(
      'transfer.initiated',
      trackingId,
      event as unknown as Record<string, unknown>,
    );

    this.lastPublishedEvent = event;

    this.logger.log(
      `Published transfer.initiated event [${trackingId}] ` +
        `${request.fromIban} -> ${request.toIban} | ${request.amount} ${request.currency}`,
    );

    return {
      trackingId,
      status: TransferStatus.PENDING,
      message: 'Transfer initiated. Processing will complete shortly.',
    };
  }

  getLastPublishedEvent(): TransferInitiatedEvent | null
  {
    return this.lastPublishedEvent;
  }
}
