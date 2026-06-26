// ============================================================
// Account ORM Entity (TypeORM)
// Hexagonal Architecture — Infrastructure Layer
// Maps the Account domain entity to the PostgreSQL `conturiBancare` table.
// ============================================================

import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity({ name: 'conturiBancare' })
export class AccountOrmEntity {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'userid', type: 'int' })
  userId!: number;

  @Column({ name: 'iban', type: 'varchar', length: 34 })
  IBAN!: string;

  @Column({ name: 'moneda', type: 'varchar', length: 3, default: 'RON' })
  moneda!: string;

  @Column({ name: 'sold', type: 'decimal', precision: 15, scale: 2, default: 0 })
  sold!: number;

  @CreateDateColumn({ name: 'createdat' })
  createdAt!: Date;
}
