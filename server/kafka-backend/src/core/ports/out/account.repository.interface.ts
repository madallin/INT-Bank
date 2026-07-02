import { Account, AccountBalance } from '../../domain/account.entity';
import { EntityManager } from 'typeorm';

export abstract class AccountRepository
{
  abstract findByIban(iban: string): Promise<Account | null>;
  abstract findById(id: number): Promise<Account | null>;

  // Pessimistic lock prevents concurrent transfer race conditions
  abstract findByIdWithLock(
    id: number,
    entityManager?: unknown,
  ): Promise<Account | null>;

  abstract updateBalance(
    accountId: number,
    newBalance: number,
    entityManager?: unknown,
  ): Promise<void>;

  abstract getBalance(accountId: number): Promise<AccountBalance>;

  // ACID transaction wrapper: all operations inside cb share one EntityManager
  abstract runInTransaction<T>(
    cb: (entityManager: EntityManager) => Promise<T>,
  ): Promise<T>;

  // Serializable isolation for critical multi-account operations
  abstract runInSerializableTransaction<T>(
    cb: (entityManager: EntityManager) => Promise<T>,
  ): Promise<T>;

  // Optimistic locking variant: find by ID with version for OCC conflict detection
  abstract findByIdWithVersion(
    id: number,
    entityManager?: unknown,
  ): Promise<{ account: Account | null; version: number }>;
}
