import
{
    Controller,
    Post,
    Body,
    UseGuards,
    Logger,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import * as twilio from 'twilio';
import { redis } from '../../../../config/redis';
import { ClientTokenGuard } from '../../../common/guards/client-token.guard';

const twilioClient = twilio(
    process.env.TWILIO_ACCOUNT_SID!,
    process.env.TWILIO_AUTH_TOKEN!,
);
const SERVICE_SID = process.env.TWILIO_SERVICE_SID!;

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

    @UseGuards(ClientTokenGuard)
    @Throttle({ default: { limit: 1, ttl: 60000 } })
    @Post('send-otp-sms')
    async sendOtpSms(@Body() body: { phone?: string })
    {
        const { phone } = body;
        if(!phone)
        {
            return { statusCode: 400, error: 'Numar de telefon lipsa' };
        }

        const lastSentKey = `otp:sms:last:${phone}`;
        const lastSent = await redis.get(lastSentKey);

        if(lastSent && Date.now() - parseInt(lastSent) < 60 * 1000)
        {
            return {
                statusCode: 429,
                error: 'Asteapta 1 minut inainte de a solicita un nou cod',
            };
        }

        try
        {
            await twilioClient.verify.v2.services(SERVICE_SID).verifications.create(
            {
                to: phone,
                channel: 'sms',
            });

            await redis.set(lastSentKey, Date.now(), 'EX', 61);
            return { success: true };
        }
        catch (err)
        {
            this.logger.error(err, 'Eroare la trimiterea SMS-ului OTP');
            return { statusCode: 500, error: 'Eroare la trimiterea SMS-ului' };
        }
    }
}
