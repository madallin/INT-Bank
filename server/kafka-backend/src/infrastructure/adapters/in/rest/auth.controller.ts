import
{
    Controller,
    Post,
    Body,
    Logger,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { redis } from '../../../../config/redis';

@Controller('auth')
export class AuthController
{
    private readonly logger = new Logger(AuthController.name);

    @Post('get-client-token')
    async getClientToken(@Body() body: { deviceId?: string })
    {
        const deviceId = body.deviceId || 'dev-device';
        try
        {
            if(!process.env.JWT_SECRET)
            {
                return { statusCode: 500, error: 'JWT secret not configured' };
            }

            const clientToken = jwt.sign(
                { deviceId },
                process.env.JWT_SECRET,
                { expiresIn: '5m' },
            );
            const refreshToken = crypto.randomBytes(32).toString('hex');

            await redis.set(
                `refresh:${deviceId}`,
                refreshToken,
                'EX',
                15 * 60,
            );

            return { client_token: clientToken, refresh_token: refreshToken };
        }
        catch (err)
        {
            this.logger.error(err, 'Error generating client token');
            return { statusCode: 500, error: 'Server error generating token' };
        }
    }

    @Post('refresh-client-token')
    async refreshClientToken(@Body() body: { deviceId?: string; refreshToken?: string })
    {
        const { deviceId, refreshToken } = body;
        if(!deviceId || !refreshToken)
        {
            return { statusCode: 400, error: 'Missing parameters' };
        }

        try
        {
            const stored = await redis.get(`refresh:${deviceId}`);
            if(!stored || stored !== refreshToken)
            {
                return { statusCode: 401, error: 'Invalid or expired refresh token' };
            }

            const newToken = jwt.sign(
                { deviceId },
                process.env.JWT_SECRET!,
                { expiresIn: '5m' },
            );
            return { client_token: newToken, ttl: 300 };
        }
        catch (err)
        {
            this.logger.error(err, 'Error refreshing client token');
            return { statusCode: 500, error: 'Server error' };
        }
    }
}
