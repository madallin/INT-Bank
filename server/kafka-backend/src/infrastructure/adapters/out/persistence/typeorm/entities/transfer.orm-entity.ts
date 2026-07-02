import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'transferuri_kafka' })
export class TransferOrmEntity
{
  @PrimaryColumn({ type: 'uuid' })
  id!: string;

  @Column({ name: 'fromaccountid', type: 'int' })
  fromAccountId!: number;

  @Column({ name: 'toaccountid', type: 'int' })
  toAccountId!: number;

  @Column({ type: 'decimal', precision: 15, scale: 2 })
  amount!: number;

  @Column({ type: 'varchar', length: 3, default: 'RON' })
  currency!: string;

  @Column({ type: 'text' })
  reason!: string;

  @Column({
    type: 'varchar',
    length: 20,
    default: 'pending',
  })
  status!: string;

  @CreateDateColumn({ name: 'initiatedat' })
  initiatedAt!: Date;

  @Column({ name: 'completedat', type: 'timestamp', nullable: true })
  completedAt?: Date;

  @Column({ name: 'failurereason', type: 'text', nullable: true })
  failureReason?: string;
}
