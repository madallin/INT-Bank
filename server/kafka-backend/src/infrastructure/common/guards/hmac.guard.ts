import
{
    Injectable,
    CanActivate,
    ExecutionContext,
    ForbiddenException,
    Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import crypto from 'crypto';
import { SKIP_HMAC_KEY } from './skip-hmac.decorator';

const HMAC_HEADER = 'x-app-signature';
const TIMESTAMP_TOLERANCE_MS = 5000;
const HEADER_REGEX = /^t=(\d+),s=([a-f0-9]{64})$/;

@Injectable()
export class HmacGuard implements CanActivate
{
    private readonly logger = new Logger(HmacGuard.name);

    constructor(private readonly reflector: Reflector) {}

    canActivate(context: ExecutionContext): boolean
    {
        const skipHmac = this.reflector.getAllAndOverride<boolean>(
            SKIP_HMAC_KEY,
            [context.getHandler(), context.getClass()],
        );
        if(skipHmac)
        {
            return true;
        }

        const request = context.switchToHttp().getRequest<Request>();

        if(request.method === 'OPTIONS')
        {
            return true;
        }

        const secret = process.env.HMAC_KEY_HEX;
        if(!secret || secret.length === 0)
        {
            this.logger.error('HMAC_KEY_HEX environment variable is not set');
            throw new ForbiddenException(
                { error: 'Signature verification unavailable', code: 'HMAC_NOT_CONFIGURED' },
            );
        }

        const rawHeader = request.headers[HMAC_HEADER];
        if(!rawHeader || typeof rawHeader !== 'string')
        {
            throw new ForbiddenException(
                { error: 'Missing application signature', code: 'HMAC_HEADER_MISSING' },
            );
        }

        const match = rawHeader.match(HEADER_REGEX);
        if(!match)
        {
            throw new ForbiddenException(
                { error: 'Invalid signature format', code: 'HMAC_FORMAT_INVALID' },
            );
        }

        const clientTimestamp = parseInt(match[1], 10);
        const clientSignature = match[2];
        const now = Date.now();

        if(Math.abs(now - clientTimestamp) > TIMESTAMP_TOLERANCE_MS)
        {
            throw new ForbiddenException(
                { error: 'Signature timestamp out of window', code: 'HMAC_TIMESTAMP_EXPIRED' },
            );
        }

        const bodyRaw =
            typeof request.body === 'object' && request.body !== null
                ? JSON.stringify(request.body)
                : '';

        const payload = `${clientTimestamp}${request.method}${request.path}${bodyRaw}`;
        const computedSignature = crypto
            .createHmac('sha256', secret)
            .update(payload)
            .digest('hex');

        if(!crypto.timingSafeEqual(
            Buffer.from(computedSignature),
            Buffer.from(clientSignature),
        ))
        {
            throw new ForbiddenException(
                { error: 'Invalid application signature', code: 'HMAC_MISMATCH' },
            );
        }

        return true;
    }
}
