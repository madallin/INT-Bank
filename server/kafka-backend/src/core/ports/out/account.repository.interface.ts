// ============================================================
// Account Repository Port (Outbound Port — Driven Side)
// Hexagonal Architecture — Ports (Core Domain)
// ============================================================

import { Account, AccountBalance } from '../../domain/account.entity';

/**
 * Secondary port (driven) for persisting and retrieving accounts.
 * Implemented by the TypeORM adapter (infrastructure layer).
 */
export abstract class AccountRepository {
  /**
   * Find an account by its IBAN.
   */
  abstract findByIban(iban: string): Promise<Account | null>;

  /**
   * Find an account by its internal ID.
   */
  abstract findById(id: number): Promise<Account | null>;

  /**
   * Lock a row for update (pessimistic lock).
   * Essential for preventing race conditions during transfers.
   */
  abstract findByIdWithLock(
    id: number,
    entityManager?: unknown,
  ): Promise<Account | null>;

  /**
   * Update the balance of an account.
   * Must be called inside a managed transaction.
   */
  abstract updateBalance(
    accountId: number,
    newBalance: number,
    entityManager?: unknown,
  ): Promise<void>;

  /**
   * Get the current balance snapshot.
   */
  abstract getBalance(accountId: number): Promise<AccountBalance>;
}
