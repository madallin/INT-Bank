import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { redis } from '../../config/redis';
import { AccountOrmEntity } from '../adapters/out/persistence/typeorm/entities/account.orm-entity';
import { TransferOrmEntity } from '../adapters/out/persistence/typeorm/entities/transfer.orm-entity';

const BALANCE_CACHE_PREFIX = 'balance:';
const BALANCE_CACHE_TTL_SECONDS = 300;

interface AccountBalanceProjection
{
    accountId: number;
    iban: string;
    balance: number;
    currency: string;
    lastUpdated: string;
}

interface TransferHistoryProjection
{
    transferId: string;
    fromIban: string;
    toIban: string;
    amount: number;
    currency: string;
    status: string;
    reason: string;
    initiatedAt: string;
    completedAt?: string;
}

@Injectable()
export class ReadModelProjectorService
{
    private readonly logger = new Logger(ReadModelProjectorService.name);

    constructor(
        @InjectDataSource()
        private readonly dataSource: DataSource,
    ) {}

    async getAccountBalance(accountId: number): Promise<AccountBalanceProjection | null>
    {
        // Fast path: serve from Redis cache; falls back to DB on miss
        const cacheKey = `${BALANCE_CACHE_PREFIX}${accountId}`;

        try
        {
            const cached = await redis.get(cacheKey);
            if(cached)
            {
                return JSON.parse(cached) as AccountBalanceProjection;
            }
        }
        catch(err)
        {
            this.logger.warn(`Redis read failed for balance cache: ${cacheKey}`, err);
        }

        const accountRepo = this.dataSource.getRepository(AccountOrmEntity);
        const entity = await accountRepo.findOne({ where: { id: accountId } });

        if(!entity)
        {
            return null;
        }

        const projection: AccountBalanceProjection = {
            accountId: entity.id,
            iban: entity.IBAN,
            balance: Number(entity.sold),
            currency: entity.moneda,
            lastUpdated: new Date().toISOString(),
        };

        try
        {
            await redis.setex(cacheKey, BALANCE_CACHE_TTL_SECONDS, JSON.stringify(projection));
        }
        catch(err)
        {
            this.logger.warn(`Failed to cache balance for account ${accountId}`, err);
        }

        return projection;
    }

    async invalidateBalanceCache(accountId: number): Promise<void>
    {
        const cacheKey = `${BALANCE_CACHE_PREFIX}${accountId}`;

        try
        {
            await redis.del(cacheKey);
        }
        catch(err)
        {
            this.logger.warn(`Failed to invalidate balance cache for account ${accountId}`, err);
        }
    }

    async getTransferHistory(
        accountId: number,
        limit: number = 20,
        offset: number = 0,
    ): Promise<TransferHistoryProjection[]>
    {
        const transferRepo = this.dataSource.getRepository(TransferOrmEntity);
        const entities = await transferRepo.find({
            where: [
                { fromAccountId: accountId },
                { toAccountId: accountId },
            ],
            order: { initiatedAt: 'DESC' },
            skip: offset,
            take: limit,
        });

        // Enrich with IBANs from the balance cache to avoid N+1 queries
        const ibanCache = new Map<number, string>();

        return await Promise.all(
            entities.map(async (t) =>
            {
                if(!ibanCache.has(t.fromAccountId))
                {
                    const bal = await this.getAccountBalance(t.fromAccountId);
                    ibanCache.set(
                        t.fromAccountId,
                        bal?.iban ?? `Account#${t.fromAccountId}`,
                    );
                }

                if(!ibanCache.has(t.toAccountId))
                {
                    const bal = await this.getAccountBalance(t.toAccountId);
                    ibanCache.set(
                        t.toAccountId,
                        bal?.iban ?? `Account#${t.toAccountId}`,
                    );
                }

                return {
                    transferId: t.id,
                    fromIban: ibanCache.get(t.fromAccountId)!,
                    toIban: ibanCache.get(t.toAccountId)!,
                    amount: Number(t.amount),
                    currency: t.currency,
                    status: t.status,
                    reason: t.reason,
                    initiatedAt: t.initiatedAt.toISOString(),
                    completedAt: t.completedAt?.toISOString(),
                };
            }),
        );
    }

    async getAccountStats(accountId: number): Promise<{
        totalSent: number;
        totalReceived: number;
        transferCount: number;
        lastTransferAt: string | null;
    }>
    {
        const transferRepo = this.dataSource.getRepository(TransferOrmEntity);

        const [sentResult, receivedResult, lastTransfer] = await Promise.all([
            transferRepo
                .createQueryBuilder('t')
                .select('SUM(t.amount)', 'total')
                .where('t.fromAccountId = :accountId', { accountId })
                .andWhere('t.status = :status', { status: 'completed' })
                .getRawOne(),

            transferRepo
                .createQueryBuilder('t')
                .select('SUM(t.amount)', 'total')
                .where('t.toAccountId = :accountId', { accountId })
                .andWhere('t.status = :status', { status: 'completed' })
                .getRawOne(),

            transferRepo.findOne({
                where: [
                    { fromAccountId: accountId },
                    { toAccountId: accountId },
                ],
                order: { initiatedAt: 'DESC' },
            }),
        ]);

        return {
            totalSent: Number(sentResult?.total ?? 0),
            totalReceived: Number(receivedResult?.total ?? 0),
            transferCount: await transferRepo.count({
                where: [
                    { fromAccountId: accountId },
                    { toAccountId: accountId },
                ],
            }),
            lastTransferAt: lastTransfer?.initiatedAt?.toISOString() ?? null,
        };
    }
}