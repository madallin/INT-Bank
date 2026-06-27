import
{
    Controller,
    Post,
    Body,
    UseGuards,
    Logger,
} from '@nestjs/common';
import twilio from 'twilio';
import { redis } from '../../../../config/redis';
import { ClientTokenGuard } from '../../../common/guards/client-token.guard';

const twilioClient = twilio(
    process.env.TWILIO_ACCOUNT_SID!,
    process.env.TWILIO_AUTH_TOKEN!,
);
const SERVICE_SID = process.env.TWILIO_SERVICE_SID!;

@Controller('2fa')
export class TwoFAController
{
    private readonly logger = new Logger(TwoFAController.name);

    @UseGuards(ClientTokenGuard)
    @Post('request')
    async requestCode(@Body() body: { phone?: string })
    {
        const { phone } = body;
        if(!phone)
        {
            return { statusCode: 400, error: 'Numar de telefon lipsa' };
        }

        const lastSentKey = `2fa:last:${phone}`;
        const lastSent = await redis.get(lastSentKey);

        if(lastSent && Date.now() - parseInt(lastSent) < 60 * 1000)
        {
            return {
                statusCode: 429,
                error: 'Asteapta 1 minut inainte de a retrimite codul',
            };
        }

        try
        {
            await twilioClient.verify.v2.services(SERVICE_SID).verifications.create(
            {
                to: phone,
                channel: 'sms',
            });

            await redis.set(lastSentKey, Date.now(), 'EX', 60);
            return { success: true };
        }
        catch (err)
        {
            this.logger.error(err, 'Eroare la trimiterea SMS-ului');
            return { statusCode: 500, error: 'Eroare la trimiterea SMS-ului' };
        }
    }

    @UseGuards(ClientTokenGuard)
    @Post('verify')
    async verifyCode(@Body() body: { phone?: string; code?: string })
    {
        const { phone, code } = body;
        if(!phone || phone.length <= 4 || !code)
        {
            return { statusCode: 400, error: 'Parametri lipsa' };
        }

        try
        {
            const check = await twilioClient.verify.v2.services(SERVICE_SID)
                .verificationChecks.create(
                {
                    to: phone,
                    code,
                });

            if(check.status === 'approved')
            {
                return { success: true, status: check.status };
            }
            else
            {
                return { statusCode: 400, success: false, status: check.status };
            }
        }
        catch (twErr: any)
        {
            this.logger.error(twErr, 'Twilio verify error');

            if(twErr.code === 60202)
            {
                return {
                    statusCode: 429,
                    error: 'Ai depasit numarul maxim de incercari. Retrimite codul.',
                };
            }

            if(twErr.code === 20404)
            {
                return {
                    statusCode: 400,
                    error: 'Codul de verificare este invalid sau a expirat.',
                };
            }

            const msg =
                (twErr && (twErr.message || (twErr.error && twErr.error.message))) ||
                'Eroare la verificarea codului';
            return { statusCode: 500, error: msg };
        }
    }
}
