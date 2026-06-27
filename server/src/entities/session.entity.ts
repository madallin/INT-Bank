import
{
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
} from 'typeorm';

@Entity({ name: 'sesiuni' })
export class SessionEntity
{
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ name: 'user_id', type: 'int' })
    userId!: number;

    @Column({ name: 'jti', type: 'uuid', unique: true, default: () => 'gen_random_uuid()' })
    jti!: string;

    @Column({ name: 'refresh_token_hash', type: 'text' })
    refreshTokenHash!: string;

    @Column({ name: 'expires_at', type: 'timestamp' })
    expiresAt!: Date;

    @CreateDateColumn({ name: 'created_at' })
    createdAt!: Date;
}
