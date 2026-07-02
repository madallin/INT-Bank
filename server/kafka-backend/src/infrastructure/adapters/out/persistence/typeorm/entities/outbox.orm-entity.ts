import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

export enum OutboxStatus
{
  PENDING = 'PENDING',
  SENT = 'SENT',
  DEAD = 'DEAD',
}

@Entity({ name: 'outbox' })
@Index(['status', 'createdAt'])
export class OutboxOrmEntity
{
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'aggregate_id', type: 'varchar', length: 64 })
  aggregateId!: string;

  @Column({ name: 'event_type', type: 'varchar', length: 128 })
  eventType!: string;

  @Column({ name: 'topic', type: 'varchar', length: 128 })
  topic!: string;

  @Column({ name: 'partition_key', type: 'varchar', length: 64 })
  partitionKey!: string;

  @Column({ name: 'payload', type: 'jsonb' })
  payload!: Record<string, unknown>;

  @Column({
    name: 'status',
    type: 'varchar',
    length: 20,
    default: OutboxStatus.PENDING,
  })
  status!: OutboxStatus;

  @Column({ name: 'retry_count', type: 'int', default: 0 })
  retryCount!: number;

  @Column({ name: 'last_error', type: 'text', nullable: true })
  lastError?: string;

  @Column({ name: 'max_retries', type: 'int', default: 5 })
  maxRetries!: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}