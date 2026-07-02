import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';

@Controller()
@SkipThrottle()
export class HealthController
{
    @Get('health')
    getHealth(): { status: string }
    {
        return { status: 'ok' };
    }
}
