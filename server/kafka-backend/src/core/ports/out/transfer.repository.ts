// ============================================================
// Outbound Port: TransferRepository
// Hexagonal Architecture — Core Domain Layer
// This interface defines how the application accesses Transfer
// persistence. The implementation lives in the Infrastructure layer.
// ============================================================

import { Transfer } from '../../domain/entities/transfer.entity';

export abstract class TransferRepository {
  /**
   * Persist a new transfer.
   */
  abstract save(transfer: Transfer): Promise<void>;

  /**
   * Find a transfer by its tracking ID.
   */
  abstract findById(id: string): Promise<Transfer | null>;

  /**
   * Find all transfers for a given account (sent or received).
   */
  abstract findByAccountId(accountId: string): Promise<Transfer[]>;

  /**
   * Update an existing transfer's status.
   */
  abstract updateStatus(
    id: string,
    status: string,
    failureReason?: string | null,
  ): Promise<void>;
}
