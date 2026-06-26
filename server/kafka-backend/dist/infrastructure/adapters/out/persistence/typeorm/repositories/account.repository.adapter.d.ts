import { Repository } from 'typeorm';
import { AccountRepository } from '../../../../../../core/ports/out/account.repository.interface';
import { Account, AccountBalance } from '../../../../../../core/domain/account.entity';
import { AccountOrmEntity } from '../entities/account.orm-entity';
export declare class AccountRepositoryAdapter implements AccountRepository {
    private readonly repo;
    private readonly logger;
    constructor(repo: Repository<AccountOrmEntity>);
    findByIban(iban: string): Promise<Account | null>;
    findById(id: number): Promise<Account | null>;
    findByIdWithLock(id: number, entityManager?: unknown): Promise<Account | null>;
    updateBalance(accountId: number, newBalance: number, entityManager?: unknown): Promise<void>;
    getBalance(accountId: number): Promise<AccountBalance>;
    private toDomain;
}
