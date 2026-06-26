// ============================================================
// Transfer Repository Adapter (TypeORM)
// Hexagonal Architecture — Infrastructure Layer
// Implements the TransferRepository port using TypeORM.
// ============================================================

import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { TransferRepository } from '../../../../../../core/ports/out/transfer.repository.interface';
import {
  Transfer,
  TransferStatus,
} from '../../../../../../core/domain/transfer.entity';
import { TransferOrmEntity } from '../entities/transfer.orm-entity';

@Injectable()
export class TransferRepositoryAdapter implements TransferRepository {
  constructor(
    @InjectRepository(TransferOrmEntity)
    private readonly repo: Repository<TransferOrmEntity>,
  ) {}

  async save(transfer: Transfer): Promise<Transfer> {
    const entity = this.toEntity(transfer);
    const saved = await this.repo.save(entity);
    return this.toDomain(saved);
  }

  async findById(id: string): Promise<Transfer | null> {
    const entity = await this.repo.findOne({ where: { id } });
    return entity ? this.toDomain(entity) : null;
  }

  async updateStatus(
    id: string,
    status: TransferStatus,
    completedAt?: Date,
    failureReason?: string,
  ): Promise<void> {
    const updateData: Partial<TransferOrmEntity> = {
      status,
    };
    if (completedAt !== undefined) {
      updateData.completedAt = completedAt;
    }
    if (failureReason !== undefined) {
      updateData.failureReason = failureReason;
    }
    await this.repo.update(id, updateData);
  }

  async findByAccountId(accountId: number): Promise<Transfer[]> {
    const entities = await this.repo.find({
      where: [
        { fromAccountId: accountId },
        { toAccountId: accountId },
      ],
      order: { initiatedAt: 'DESC' },
      take: 50,
    });

    return entities.map((e) => this.toDomain(e));
  }

  private toDomain(entity: TransferOrmEntity): Transfer {
    return {
      id: entity.id,
      fromAccountId: entity.fromAccountId,
      toAccountId: entity.toAccountId,
      amount: entity.amount,
      currency: entity.currency,
      reason: entity.reason,
      status: entity.status as TransferStatus,
      initiatedAt: entity.initiatedAt,
      completedAt: entity.completedAt,
      failureReason: entity.failureReason,
    };
  }

  private toEntity(domain: Transfer): TransferOrmEntity {
    const entity = new TransferOrmEntity();
    entity.id = domain.id;
    entity.fromAccountId = domain.fromAccountId;
    entity.toAccountId = domain.toAccountId;
    entity.amount = domain.amount;
    entity.currency = domain.currency;
    entity.reason = domain.reason;
    entity.status = domain.status;
    entity.initiatedAt = domain.initiatedAt;
    entity.completedAt = domain.completedAt;
    entity.failureReason = domain.failureReason;
    return entity;
  }
}
