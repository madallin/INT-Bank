import {
  Transfer,
  TransferStatus,
} from '../../domain/transfer.entity';

export abstract class TransferRepository
{
  abstract save(transfer: Transfer): Promise<Transfer>;
  abstract findById(id: string): Promise<Transfer | null>;
  abstract updateStatus(
    id: string,
    status: TransferStatus,
    completedAt?: Date,
    failureReason?: string,
  ): Promise<void>;
  abstract findByAccountId(accountId: number): Promise<Transfer[]>;
}
