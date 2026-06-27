import
{
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'utilizatori' })
export class UserOrmEntity
{
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ name: 'nume', type: 'varchar', length: 255 })
    nume!: string;

    @Column({ name: 'prenume', type: 'varchar', length: 255 })
    prenume!: string;

    @Column({ name: 'email', type: 'varchar', length: 255, unique: true })
    email!: string;

    @Column({ name: 'nrtelefon', type: 'varchar', length: 20 })
    nrTelefon!: string;

    @Column({ name: 'sex', type: 'varchar', length: 10 })
    sex!: string;

    @Column({ name: 'datanasterii', type: 'date' })
    dataNasterii!: string;

    @Column({ name: 'cnp', type: 'varchar', length: 13, unique: true })
    cnp!: string;

    @Column({ name: 'pincont', type: 'varchar', length: 255, nullable: true })
    pinCont!: string | null;

    @Column({ name: 'contaprobat', type: 'boolean', default: false })
    contAprobat!: boolean;

    @Column({ name: 'termeniacceptati', type: 'boolean', default: false })
    termeniAcceptati!: boolean;

    @Column({ name: 'judet', type: 'varchar', length: 255, nullable: true })
    judet!: string | null;

    @Column({ name: 'localitate', type: 'varchar', length: 255, nullable: true })
    localitate!: string | null;

    @Column({ name: 'adresa', type: 'text', nullable: true })
    adresa!: string | null;

    @Column({ name: 'cod_postal', type: 'varchar', length: 20, nullable: true })
    codPostal!: string | null;

    @Column({ name: 'place_id', type: 'varchar', length: 255, nullable: true })
    placeId!: string | null;

    @Column({ name: 'lat', type: 'decimal', precision: 10, scale: 7, nullable: true })
    lat!: number | null;

    @Column({ name: 'lng', type: 'decimal', precision: 10, scale: 7, nullable: true })
    lng!: number | null;

    @Column({ name: 'bloc', type: 'varchar', length: 50, nullable: true })
    bloc!: string | null;

    @Column({ name: 'scara', type: 'varchar', length: 50, nullable: true })
    scara!: string | null;

    @Column({ name: 'apartament', type: 'varchar', length: 50, nullable: true })
    apartament!: string | null;

    @CreateDateColumn({ name: 'createdat' })
    createdAt!: Date;

    @UpdateDateColumn({ name: 'updatedat' })
    updatedAt!: Date;
}
