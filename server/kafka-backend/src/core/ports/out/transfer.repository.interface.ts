// ============================================================
// Transfer Repository Port (Outbound Port — Driven Side)
// Hexagonal Architecture — Ports (Core Domain)
// ============================================================

import {
  Transfer,
  TransferStatus,
} from '../../domain/transfer.entity';

/**
 * Secondary port (driven) for persisting transfers.
 * Implemented by the TypeORM adapter (infrastructure layer).
 */
export abstract class TransferRepository {
  /**
   * Save a new transfer record.
   */
  abstract save(transfer: Transfer): Promise<Transfer>;

  /**
   * Find a transfer by its ID.
   */
  abstract findById(id: string): Promise<Transfer | null>;

  /**
   * Update the status of a transfer.
   */
  abstract updateStatus(
    id: string,
    status: TransferStatus,
    completedAt?: Date,
    failureReason?: string,
  ): Promise<void>;

  /**
   * List all transfers for a given account.
   */
  abstract findByAccountId(accountId: number): Promise<Transfer[]>;
}
