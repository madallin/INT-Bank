import
{
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
} from 'typeorm';

@Entity({ name: 'sesiuni' })
export class SessionOrmEntity
{
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ name: 'user_id', type: 'int' })
    userId!: number;

    @Column({ name: 'refresh_token_hash', type: 'text' })
    refreshTokenHash!: string;

    @Column({ name: 'expires_at', type: 'timestamp' })
    expiresAt!: Date;

    @CreateDateColumn({ name: 'created_at' })
    createdAt!: Date;
}
