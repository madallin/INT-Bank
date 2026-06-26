import { Transfer } from '../../domain/entities/transfer.entity';

export abstract class TransferRepository
{
  abstract save(transfer: Transfer): Promise<void>;
  abstract findById(id: string): Promise<Transfer | null>;
  abstract findByAccountId(accountId: string): Promise<Transfer[]>;
  abstract updateStatus(
    id: string,
    status: string,
    failureReason?: string | null,
  ): Promise<void>;
}
