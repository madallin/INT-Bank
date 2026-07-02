import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, EntityManager, DataSource } from 'typeorm';

import { AccountRepository } from '../../../../../../core/ports/out/account.repository.interface';
import { Account, AccountBalance } from '../../../../../../core/domain/account.entity';
import { AccountOrmEntity } from '../entities/account.orm-entity';

const DEFAULT_ISOLATION: 'REPEATABLE READ' = 'REPEATABLE READ';
const SERIALIZABLE_ISOLATION: 'SERIALIZABLE' = 'SERIALIZABLE';

@Injectable()
export class AccountRepositoryAdapter implements AccountRepository
{
    private readonly logger = new Logger(AccountRepositoryAdapter.name);

    constructor(
        @InjectRepository(AccountOrmEntity)
        private readonly repo: Repository<AccountOrmEntity>,
        private readonly dataSource: DataSource,
    ) {}

    async findByIban(iban: string): Promise<Account | null>
    {
        const entity = await this.repo.findOne({ where: { IBAN: iban } });
        return entity ? this.toDomain(entity) : null;
    }

    async findById(id: number): Promise<Account | null>
    {
        const entity = await this.repo.findOne({ where: { id } });
        return entity ? this.toDomain(entity) : null;
    }

    async findByIdWithLock(
        id: number,
        entityManager?: unknown,
    ): Promise<Account | null>
    {
        if(entityManager)
        {
            const em = entityManager as EntityManager;
            const entity = await em.findOne(AccountOrmEntity, {
                where: { id },
                lock: { mode: 'pessimistic_write' },
            });
            return entity ? this.toDomain(entity) : null;
        }

        const entity = await this.repo.findOne({
            where: { id },
            lock: { mode: 'pessimistic_write' },
        });
        return entity ? this.toDomain(entity) : null;
    }

    async updateBalance(
        accountId: number,
        newBalance: number,
        entityManager?: unknown,
    ): Promise<void>
    {
        if(entityManager)
        {
            const em = entityManager as EntityManager;
            await em.update(AccountOrmEntity, accountId, { sold: newBalance });
        }
        else
        {
            await this.repo.update(accountId, { sold: newBalance });
        }

        this.logger.debug(
            `Account ${accountId} balance updated to ${newBalance}`,
        );
    }

    async getBalance(accountId: number): Promise<AccountBalance>
    {
        const entity = await this.repo.findOne({ where: { id: accountId } });
        if(!entity)
        {
            throw new NotFoundException(`Account ${accountId} not found`);
        }

        return {
            accountId: entity.id,
            IBAN: entity.IBAN,
            moneda: entity.moneda,
            sold: entity.sold,
        };
    }

    async runInTransaction<T>(
        fn: (em: EntityManager) => Promise<T>,
    ): Promise<T>
    {
        return await this.dataSource.transaction(DEFAULT_ISOLATION, fn);
    }

    async runInSerializableTransaction<T>(
        fn: (em: EntityManager) => Promise<T>,
    ): Promise<T>
    {
        return await this.dataSource.transaction(SERIALIZABLE_ISOLATION, fn);
    }

    async findByIdWithVersion(
        id: number,
        entityManager?: unknown,
    ): Promise<{ account: Account | null; version: number }>
    {
        const em = entityManager
            ? (entityManager as EntityManager)
            : this.repo.manager;

        const entity = await em.findOne(AccountOrmEntity, {
            where: { id },
        });

        return {
            account: entity ? this.toDomain(entity) : null,
            version: entity?.version ?? 0,
        };
    }

    private toDomain(entity: AccountOrmEntity): Account
    {
        return {
            id: entity.id,
            userId: entity.userId,
            IBAN: entity.IBAN,
            moneda: entity.moneda,
            sold: entity.sold,
            createdAt: entity.createdAt,
        };
    }
}
