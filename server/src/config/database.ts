import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { UserEntity } from '../entities/user.entity';
import { AccountEntity } from '../entities/account.entity';
import { CardEntity } from '../entities/card.entity';
import { TransferEntity } from '../entities/transfer.entity';
import { SessionEntity } from '../entities/session.entity';

export const AppDataSource = new DataSource(
{
    type: 'postgres',
    url: process.env.DATABASE_URL || undefined,
    host: process.env.DATABASE_URL ? undefined : (process.env.PGHOST || 'localhost'),
    port: process.env.DATABASE_URL ? undefined : (process.env.PGPORT ? Number(process.env.PGPORT) : 5432),
    username: process.env.DATABASE_URL ? undefined : (process.env.PGUSER || 'postgres'),
    password: process.env.DATABASE_URL ? undefined : (process.env.PGPASSWORD || 'postgres'),
    database: process.env.DATABASE_URL ? undefined : (process.env.PGDATABASE || 'internet_banking'),
    entities: [
        UserEntity,
        AccountEntity,
        CardEntity,
        TransferEntity,
        SessionEntity,
    ],
    synchronize: process.env.NODE_ENV !== 'production',
    logging: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
    ssl:
        process.env.DB_SSL === 'true'
            ? { rejectUnauthorized: false }
            : false,
    poolSize: process.env.PGPOOL_MAX ? Number(process.env.PGPOOL_MAX) : 20,
    extra:
    {
        idleTimeoutMillis: process.env.PG_IDLE_MS ? Number(process.env.PG_IDLE_MS) : 30000,
        connectionTimeoutMillis: process.env.PG_CONN_TIMEOUT_MS ? Number(process.env.PG_CONN_TIMEOUT_MS) : 2000,
    },
});
