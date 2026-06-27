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

@Controller('login')
export class LoginController
{
    private readonly logger = new Logger(LoginController.name);

    constructor(
        @InjectDataSource()
        private readonly dataSource: DataSource,
    ) {}

    @Post()
    @HttpCode(HttpStatus.OK)
    async login(@Body() body: { phone?: string })
    {
        const { phone } = body;

        if(!phone || typeof phone !== 'string')
        {
            return { statusCode: 400, error: 'Numar de telefon invalid' };
        }

        try
        {
            const userRepo = this.dataSource.getRepository(UserOrmEntity);
            const user = await userRepo.findOne(
            {
                where: { nrTelefon: phone },
                select: { id: true, contAprobat: true, termeniAcceptati: true },
            });

            if(!user)
            {
                return { exists: false };
            }

            return {
                exists: true,
                userId: user.id,
                approved: user.contAprobat,
                acceptedterms: user.termeniAcceptati,
            };
        }
        catch (err)
        {
            this.logger.error(err, 'Eroare la baza de date (login)');
            return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' };
        }
    }
}
