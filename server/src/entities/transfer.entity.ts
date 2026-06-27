import
{
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
} from 'typeorm';

@Entity({ name: 'transferuri' })
export class TransferEntity
{
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ name: 'expeditor', type: 'int' })
    expeditor!: number;

    @Column({ name: 'receptor', type: 'int' })
    receptor!: number;

    @Column({ name: 'suma', type: 'decimal', precision: 15, scale: 2 })
    suma!: number;

    @Column({ name: 'moneda', type: 'varchar', length: 3 })
    moneda!: string;

    @Column({ name: 'motiv', type: 'text', nullable: true })
    motiv!: string | null;

    @CreateDateColumn({ name: 'datatransfer' })
    dataTransfer!: Date;
}
