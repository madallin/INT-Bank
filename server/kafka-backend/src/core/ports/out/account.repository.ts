import { Account } from '../../domain/entities/account.entity';

export abstract class AccountRepository
{
  abstract findById(id: string): Promise<Account | null>;
  abstract findByIban(iban: string): Promise<Account | null>;
  abstract save(account: Account): Promise<void>;
  abstract transaction<T>(fn: (repo: AccountRepository) => Promise<T>): Promise<T>;
}
