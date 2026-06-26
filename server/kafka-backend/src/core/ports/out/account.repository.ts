// ============================================================
// Outbound Port: AccountRepository
// Hexagonal Architecture — Core Domain Layer
// This interface defines how the application accesses Account
// persistence. The implementation lives in the Infrastructure
// layer (e.g., TypeORM, Prisma, in-memory).
// ============================================================

import { Account } from '../../domain/entities/account.entity';

export abstract class AccountRepository {
  /**
   * Find an account by its unique ID.
   */
  abstract findById(id: string): Promise<Account | null>;

  /**
   * Find an account by its IBAN.
   */
  abstract findByIban(iban: string): Promise<Account | null>;

  /**
   * Persist (create or update) an account.
   */
  abstract save(account: Account): Promise<void>;

  /**
   * Execute operations inside an ACID transaction.
   * Returns the result of the callback.
   */
  abstract transaction<T>(fn: (repo: AccountRepository) => Promise<T>): Promise<T>;
}
