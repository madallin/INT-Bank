import { Account, AccountBalance } from '../../domain/account.entity';

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
}
