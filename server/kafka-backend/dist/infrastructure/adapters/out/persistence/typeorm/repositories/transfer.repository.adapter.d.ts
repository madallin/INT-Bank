import { Repository } from 'typeorm';
import { TransferRepository } from '../../../../../../core/ports/out/transfer.repository.interface';
import { Transfer, TransferStatus } from '../../../../../../core/domain/transfer.entity';
import { TransferOrmEntity } from '../entities/transfer.orm-entity';
export declare class TransferRepositoryAdapter implements TransferRepository {
    private readonly repo;
    constructor(repo: Repository<TransferOrmEntity>);
    save(transfer: Transfer): Promise<Transfer>;
    findById(id: string): Promise<Transfer | null>;
    updateStatus(id: string, status: TransferStatus, completedAt?: Date, failureReason?: string): Promise<void>;
    findByAccountId(accountId: number): Promise<Transfer[]>;
    private toDomain;
    private toEntity;
}
