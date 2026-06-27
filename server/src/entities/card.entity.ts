import
{
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
} from 'typeorm';

@Entity({ name: 'carduri' })
export class CardEntity
{
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ name: 'userid', type: 'int' })
    userId!: number;

    @Column({ name: 'numarcard', type: 'text' })
    numarCard!: string;

    @Column({ name: 'cvv', type: 'text' })
    cvv!: string;

    @Column({ name: 'dataexpirare', type: 'text' })
    dataExpirare!: string;

    @Column({ name: 'detinator', type: 'varchar', length: 255, default: '' })
    detinator!: string;

    @Column({ name: 'token', type: 'varchar', length: 255 })
    token!: string;

    @Column({ name: 'accountid', type: 'int' })
    accountId!: number;

    @CreateDateColumn({ name: 'createdat' })
    createdAt!: Date;
}
