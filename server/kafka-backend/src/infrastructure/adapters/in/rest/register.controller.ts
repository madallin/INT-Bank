import
{
    Controller,
    Post,
    Body,
    Logger,
    HttpCode,
    HttpStatus,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { UserOrmEntity } from '../../out/persistence/typeorm/entities/user.orm-entity';

@Controller('register')
export class RegisterController
{
    private readonly logger = new Logger(RegisterController.name);

    constructor(
        @InjectDataSource()
        private readonly dataSource: DataSource,
    ) {}

    @Post()
    @HttpCode(HttpStatus.CREATED)
    async register(@Body() body: any)
    {
        const {
            nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
            judet, localitate, strada, numar, bloc, scara, apartament,
            codPostal, placeId, lat, lng,
        } = body;

        if(!nume || !prenume || !email || !nrtelefon || !sex || !datanasterii || !cnp)
        {
            return { statusCode: 400, error: 'Toate campurile sunt obligatorii' };
        }

        const addressParts = [
            strada,
            numar ? `Nr. ${numar}` : '',
            bloc ? `Bl. ${bloc}` : '',
            scara ? `Sc. ${scara}` : '',
            apartament ? `Ap. ${apartament}` : '',
        ].filter(Boolean);

        try
        {
            const userRepo = this.dataSource.getRepository(UserOrmEntity);
            const user = userRepo.create(
            {
                nume, prenume, email,
                nrTelefon: nrtelefon, sex,
                dataNasterii: datanasterii, cnp,
                judet, localitate,
                adresa: addressParts.join(', '),
                codPostal: codPostal || null,
                placeId: placeId || null,
                lat: lat || null, lng: lng || null,
                bloc: bloc || null, scara: scara || null,
                apartament: apartament || null,
            });
            const saved = await userRepo.save(user);

            this.logger.log(`User registered: id=${saved.id}`);
            return { success: true, user: { id: saved.id } };
        }
        catch (err: any)
        {
            this.logger.error(err, 'Eroare la baza de date (register)');
            if(err.code === '23505')
            {
                return { statusCode: 400, error: 'Email sau CNP deja existent' };
            }
            return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' };
        }
    }
}
