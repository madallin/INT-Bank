import { Injectable, Logger } from '@nestjs/common';
import { EntityManager } from 'typeorm';

import { AccountRepository } from '../../core/ports/out/account.repository.interface';
import { TransferRepository } from '../../core/ports/out/transfer.repository.interface';
import { EventPublisher } from '../../core/ports/out/event-publisher.interface';
import { TransferStatus } from '../../core/domain/transfer.entity';
import type
{
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
            // ACID TRANSACTION: all-or-nothing for debit + credit + status update
            await this.accountRepository.runInTransaction(
                async (entityManager: EntityManager) =>
                {
                    const sender = await this.accountRepository.findByIdWithLock(
                        fromAccountId,
                        entityManager,
                    );
                    const receiver = await this.accountRepository.findByIdWithLock(
                        toAccountId,
                        entityManager,
                    );

                    if(!sender)
                    {
                        throw new Error(
                            `Sender account ${fromAccountId} not found (transfer ${transferId})`,
                        );
                    }
                    if(!receiver)
                    {
                        throw new Error(
                            `Receiver account ${toAccountId} not found (transfer ${transferId})`,
                        );
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

                    const newSenderBalance = parseFloat(
                        (senderSold - amount).toFixed(2),
                    );
                    const newReceiverBalance = parseFloat(
                        (Number(receiver.sold) + amount).toFixed(2),
                    );

                    // Debit sender
                    await this.accountRepository.updateBalance(
                        fromAccountId,
                        newSenderBalance,
                        entityManager,
                    );

                    // Credit receiver
                    await this.accountRepository.updateBalance(
                        toAccountId,
                        newReceiverBalance,
                        entityManager,
                    );

                    // Update transfer status (within same transaction)
                    await this.transferRepository.updateStatus(
                        transferId,
                        TransferStatus.COMPLETED,
                        new Date(),
                    );

                    this.logger.log(
                        `Transfer [${transferId}] funds moved: ${fromAccountId} (-${amount}) ${toAccountId} (+${amount})`,
                    );
                });

            // Outside transaction: publish event (compensating action if needed)
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

            this.logger.log(`Transfer [${transferId}] completed successfully`);
        }
        catch (error)
        {
            const errMsg =
                error instanceof Error ? error.message : 'Unknown processing error';

            // Transaction already rolled back; update status separately
            await this.transferRepository.updateStatus(
                transferId,
                TransferStatus.FAILED,
                undefined,
                errMsg,
            );

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

            this.logger.error(
                { err: error },
                `Transfer [${transferId}] failed: ${errMsg}`,
            );
        }
    }

    private delay(ms: number): Promise<void>
    {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }
}
