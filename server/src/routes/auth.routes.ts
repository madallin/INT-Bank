import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { AppDataSource } from '../config/database';
import { SessionEntity } from '../entities/session.entity';
import { UserEntity } from '../entities/user.entity';
import { ACCESS_TOKEN_TTL, REFRESH_TOKEN_TTL } from '../config/constants';
import verifyUserToken, { UserTokenRequest } from '../middleware/verifyUserToken';
import { loginLimiter } from '../middleware/rateLimiter';

const router = Router();

const BCRYPT_ROUNDS = 12;

interface RefreshPayload
{
    userId: number;
    jti: string;
    type: 'refresh';
}

function signAccessToken(userId: number, role?: string): string
{
    return jwt.sign(
        { userId, role: role || 'user' },
        process.env.JWT_SECRET!,
        { expiresIn: ACCESS_TOKEN_TTL },
    );
}

function signRefreshToken(userId: number, jti: string): string
{
    return jwt.sign(
        { userId, jti, type: 'refresh' },
        process.env.JWT_SECRET!,
        { expiresIn: REFRESH_TOKEN_TTL },
    );
}

router.post(
    '/auth-session/login',
    loginLimiter,
    async (req: Request, res: Response): Promise<void> =>
    {
        try
        {
            const { phone, pin } = req.body;

            if(!phone || !pin)
            {
                res.status(400).json({ error: 'Phone and pin are required', code: 'MISSING_CREDENTIALS' });
                return;
            }

            const userRepo = AppDataSource.getRepository(UserEntity);
            const user = await userRepo.findOne({ where: { nrTelefon: phone } });

            if(!user)
            {
                res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS' });
                return;
            }

            if(!user.pinCont)
            {
                res.status(401).json({ error: 'Pin not set', code: 'PIN_NOT_SET' });
                return;
            }

            const pinValid = await bcrypt.compare(pin, user.pinCont);
            if(!pinValid)
            {
                res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS' });
                return;
            }

            const sessionRepo = AppDataSource.getRepository(SessionEntity);

            const jti = crypto.randomUUID();
            const refreshToken = signRefreshToken(user.id, jti);
            const refreshTokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);

            const expiresAt = new Date();
            expiresAt.setDate(expiresAt.getDate() + 7);

            const session = sessionRepo.create(
            {
                userId: user.id,
                jti,
                refreshTokenHash,
                expiresAt,
            });
            await sessionRepo.save(session);

            const accessToken = signAccessToken(user.id);

            res.json(
            {
                accessToken,
                refreshToken,
                userId: user.id,
            });
        }
        catch(error: any)
        {
            res.status(500).json({ error: 'Internal server error', code: 'SERVER_ERROR' });
        }
    },
);

router.post(
    '/auth-session/refresh',
    async (req: Request, res: Response): Promise<void> =>
    {
        try
        {
            const { refreshToken } = req.body;

            if(!refreshToken)
            {
                res.status(401).json({ error: 'Refresh token required', code: 'REFRESH_REQUIRED' });
                return;
            }

            let payload: RefreshPayload;
            try
            {
                payload = jwt.verify(refreshToken, process.env.JWT_SECRET!) as RefreshPayload;

                if(payload.type !== 'refresh')
                {
                    res.status(401).json({ error: 'Invalid token type', code: 'REFRESH_INVALID' });
                    return;
                }
            }
            catch
            {
                res.status(401).json({ error: 'Refresh token expired or invalid', code: 'REFRESH_INVALID' });
                return;
            }

            const sessionRepo = AppDataSource.getRepository(SessionEntity);
            const session = await sessionRepo.findOne({ where: { jti: payload.jti } });

            if(!session)
            {
                res.status(401).json({ error: 'Session not found', code: 'REFRESH_INVALID' });
                return;
            }

            if(new Date() > session.expiresAt)
            {
                await sessionRepo.remove(session);
                res.status(401).json({ error: 'Refresh token expired', code: 'REFRESH_EXPIRED' });
                return;
            }

            const hashValid = await bcrypt.compare(refreshToken, session.refreshTokenHash);
            if(!hashValid)
            {
                await sessionRepo.remove(session);
                res.status(401).json({ error: 'Token reuse detected — session revoked', code: 'TOKEN_REUSE_DETECTED' });
                return;
            }

            const newJti = crypto.randomUUID();
            const newRefreshToken = signRefreshToken(payload.userId, newJti);
            const newRefreshTokenHash = await bcrypt.hash(newRefreshToken, BCRYPT_ROUNDS);

            const newExpiresAt = new Date();
            newExpiresAt.setDate(newExpiresAt.getDate() + 7);

            const newSession = sessionRepo.create(
            {
                userId: payload.userId,
                jti: newJti,
                refreshTokenHash: newRefreshTokenHash,
                expiresAt: newExpiresAt,
            });

            await sessionRepo.remove(session);
            await sessionRepo.save(newSession);

            const newAccessToken = signAccessToken(payload.userId);

            res.json(
            {
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                userId: payload.userId,
            });
        }
        catch(error: any)
        {
            res.status(500).json({ error: 'Internal server error', code: 'SERVER_ERROR' });
        }
    },
);

router.post(
    '/auth-session/logout',
    verifyUserToken,
    async (req: Request, res: Response): Promise<void> =>
    {
        try
        {
            const userReq = req as UserTokenRequest;
            const userId = userReq.userId;

            if(!userId)
            {
                res.status(401).json({ error: 'Not authenticated', code: 'NO_TOKEN' });
                return;
            }

            const sessionRepo = AppDataSource.getRepository(SessionEntity);
            await sessionRepo.delete({ userId });

            res.json({ message: 'Logged out successfully' });
        }
        catch(error: any)
        {
            res.status(500).json({ error: 'Internal server error', code: 'SERVER_ERROR' });
        }
    },
);

export default router;

