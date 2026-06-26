import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, EntityManager } from 'typeorm';

import { AccountRepository } from '../../../../../../core/ports/out/account.repository.interface';
import { Account, AccountBalance } from '../../../../../../core/domain/account.entity';
import { AccountOrmEntity } from '../entities/account.orm-entity';

@Injectable()
export class AccountRepositoryAdapter implements AccountRepository
{
  private readonly logger = new Logger(AccountRepositoryAdapter.name);

  constructor(
    @InjectRepository(AccountOrmEntity)
    private readonly repo: Repository<AccountOrmEntity>,
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
