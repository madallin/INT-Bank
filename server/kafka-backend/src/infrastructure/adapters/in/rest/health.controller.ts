import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { SkipHmac } from '../../../common/guards/skip-hmac.decorator';

@Controller()
@SkipThrottle()
@SkipHmac()
export class HealthController
{
    @Get('health')
    getHealth(): { status: string }
    {
        return { status: 'ok' };
    }
}
