import
{
    Injectable,
    CanActivate,
    ExecutionContext,
    UnauthorizedException,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';

export interface ClientPayload
{
    deviceId: string;
    iat?: number;
    exp?: number;
}

@Injectable()
export class ClientTokenGuard implements CanActivate
{
    canActivate(context: ExecutionContext): boolean
    {
        const request = context.switchToHttp().getRequest();
        const auth = request.headers.authorization;

        if(!auth || !auth.startsWith('Bearer '))
        {
            throw new UnauthorizedException(
                { error: 'Missing client token', code: 'NO_TOKEN' },
            );
        }

        const token = auth.slice(7);

        try
        {
            const payload = jwt.verify(
                token,
                process.env.JWT_SECRET!,
            ) as ClientPayload;
            request.client = payload;
            return true;
        }
        catch (err: any)
        {
            if(err.name === 'TokenExpiredError')
            {
                throw new UnauthorizedException(
                    { error: 'Token expired', code: 'TOKEN_EXPIRED' },
                );
            }
            throw new UnauthorizedException(
                { error: 'Token invalid', code: 'TOKEN_INVALID' },
            );
        }
    }
}
