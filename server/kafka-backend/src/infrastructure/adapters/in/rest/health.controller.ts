import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';

@Controller()
@SkipThrottle()
export class HealthController
{
    @Get('express_status')
    getStatus(): { status: string }
    {
        return { status: 'ok' };
    }

    @Get('health')
    getHealth(): { status: string }
    {
        return { status: 'ok' };
    }
}
