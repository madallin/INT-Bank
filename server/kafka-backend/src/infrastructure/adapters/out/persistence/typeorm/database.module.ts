// ============================================================
// Database Module (TypeORM)
// Hexagonal Architecture — Infrastructure Layer
// Configures TypeORM for PostgreSQL and registers repositories.
// ============================================================

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AccountOrmEntity } from './entities/account.orm-entity';
import { TransferOrmEntity } from './entities/transfer.orm-entity';
import { AccountRepositoryAdapter } from './repositories/account.repository.adapter';
import { TransferRepositoryAdapter } from './repositories/transfer.repository.adapter';
import { AccountRepository } from '../../../../../core/ports/out/account.repository.interface';
import { TransferRepository } from '../../../../../core/ports/out/transfer.repository.interface';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT ?? '5432', 10),
      username: process.env.DB_USERNAME || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      database: process.env.DB_NAME || 'internet_banking',
      entities: [AccountOrmEntity, TransferOrmEntity],
      synchronize: process.env.NODE_ENV !== 'production',
      logging: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
      ssl:
        process.env.DB_SSL === 'true'
          ? { rejectUnauthorized: false }
          : false,
    }),
    TypeOrmModule.forFeature([AccountOrmEntity, TransferOrmEntity]),
  ],
  providers: [
    {
      provide: AccountRepository,
      useClass: AccountRepositoryAdapter,
    },
    {
      provide: TransferRepository,
      useClass: TransferRepositoryAdapter,
    },
    AccountRepositoryAdapter,
    TransferRepositoryAdapter,
  ],
  exports: [AccountRepository, TransferRepository],
})
export class DatabaseModule {}
