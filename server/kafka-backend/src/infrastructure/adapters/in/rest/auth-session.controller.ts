import { Controller, Post, Body, Logger, HttpCode, HttpStatus } from '@nestjs/common';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { UserOrmEntity } from '../../out/persistence/typeorm/entities/user.orm-entity';
import { SessionOrmEntity } from '../../out/persistence/typeorm/entities/session.orm-entity';
import { AccountOrmEntity } from '../../out/persistence/typeorm/entities/account.orm-entity';
import { BankingService } from '../../../services/banking.service';

const SALT_ROUNDS = 12;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY_DAYS = 7;

@Controller('auth-session')
export class AuthSessionController
{
    private readonly logger = new Logger(AuthSessionController.name);

    constructor(
        @InjectDataSource() private readonly dataSource: DataSource,
        private readonly bankingService: BankingService,
    ) {}

    @Post('login')
    @HttpCode(HttpStatus.OK)
    async login(@Body() body: { phone?: string; pin?: string })
    {
        const { phone, pin } = body;
        if(!phone || !pin) return { statusCode: 400, error: 'Telefon si PIN sunt necesare' };
        try
        {
            const userRepo = this.dataSource.getRepository(UserOrmEntity);
            const user = await userRepo.findOne({ where: { nrTelefon: phone, contAprobat: true }, select: { id: true, pinCont: true } });
            if(!user || !user.pinCont) return { statusCode: 401, error: 'Cont inexistent sau neaprobat' };

            const pinMatch = await bcrypt.compare(pin, user.pinCont);
            if(!pinMatch) return { statusCode: 401, error: 'PIN incorect' };

            const accessToken = jwt.sign({ userId: user.id, role: 'user' }, process.env.JWT_SECRET!, { expiresIn: ACCESS_TOKEN_EXPIRY });
            const refreshToken = crypto.randomBytes(64).toString('hex');
            const refreshTokenHash = await bcrypt.hash(refreshToken, SALT_ROUNDS);
            const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

            await this.dataSource.transaction(async (em) =>
            {
                const repo = em.getRepository(SessionOrmEntity);
                await repo.delete({ userId: user.id });
                await repo.save(repo.create({ userId: user.id, refreshTokenHash, expiresAt }));
            });

            const accountCount = await this.dataSource.getRepository(AccountOrmEntity).count({ where: { userId: user.id } });
            if(accountCount === 0)
            {
                this.logger.log('Creare automata cont+card pentru user');
                await this.bankingService.createAccountAndCard(user.id, 'RON', 'RO');
            }
            return { accessToken, refreshToken, userId: user.id };
        }
        catch (err) { this.logger.error(err, 'Login error'); return { statusCode: 500, error: 'Eroare la autentificare' }; }
    }

    @Post('refresh')
    @HttpCode(HttpStatus.OK)
    async refresh(@Body() body: { refreshToken?: string })
    {
        const { refreshToken } = body;
        if(!refreshToken) return { statusCode: 400, error: 'Refresh token lipsa' };
        try
        {
            const repo = this.dataSource.getRepository(SessionOrmEntity);
            const sessions = await repo.find({ order: { createdAt: 'DESC' } });
            let matched = null;
            for(const row of sessions)
            {
                if(await bcrypt.compare(refreshToken, row.refreshTokenHash)) { matched = row; break; }
            }
            if(!matched || matched.expiresAt <= new Date()) return { statusCode: 401, error: 'Refresh token invalid sau expirat' };

            return await this.dataSource.transaction(async (em) =>
            {
                const r = em.getRepository(SessionOrmEntity);
                await r.delete({ id: matched!.id });
                const newAccessToken = jwt.sign({ userId: matched!.userId, role: 'user' }, process.env.JWT_SECRET!, { expiresIn: ACCESS_TOKEN_EXPIRY });
                const newRefreshToken = crypto.randomBytes(64).toString('hex');
                const newHash = await bcrypt.hash(newRefreshToken, SALT_ROUNDS);
                const newExp = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
                await r.save(r.create({ userId: matched!.userId, refreshTokenHash: newHash, expiresAt: newExp }));
                return { accessToken: newAccessToken, refreshToken: newRefreshToken };
            });
        }
        catch (err) { this.logger.error(err, 'Refresh error'); return { statusCode: 500, error: 'Eroare la reimprospatarea sesiunii' }; }
    }

    @Post('logout')
    @HttpCode(HttpStatus.OK)
    async logout(@Body() body: { refreshToken?: string })
    {
        const { refreshToken } = body;
        if(!refreshToken) return { statusCode: 400, error: 'Refresh token lipsa' };
        try
        {
            const repo = this.dataSource.getRepository(SessionOrmEntity);
            const sessions = await repo.find();
            for(const row of sessions)
            {
                if(await bcrypt.compare(refreshToken, row.refreshTokenHash)) { await repo.delete({ id: row.id }); break; }
            }
            return { success: true };
        }
        catch (err) { this.logger.error(err, 'Logout error'); return { statusCode: 500, error: 'Eroare la delogare' }; }
    }
}
