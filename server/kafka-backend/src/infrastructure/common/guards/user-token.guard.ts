import
{
    Injectable,
    CanActivate,
    ExecutionContext,
    UnauthorizedException,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';

export interface UserPayload
{
    userId: number;
    role?: string;
    iat?: number;
    exp?: number;
}

@Injectable()
export class UserTokenGuard implements CanActivate
{
    canActivate(context: ExecutionContext): boolean
    {
        const request = context.switchToHttp().getRequest();
        const auth = request.headers.authorization;

        if(!auth || !auth.startsWith('Bearer '))
        {
            throw new UnauthorizedException(
                { error: 'Missing access token', code: 'NO_TOKEN' },
            );
        }

        const token = auth.slice(7);

        try
        {
            const payload = jwt.verify(
                token,
                process.env.JWT_SECRET!,
            ) as UserPayload;
            request.userId = payload.userId;
            request.userRole = payload.role || 'user';
            return true;
        }
        catch (err: any)
        {
            if(err.name === 'TokenExpiredError')
            {
                throw new UnauthorizedException(
                    { error: 'Access token expired', code: 'TOKEN_EXPIRED' },
                );
            }
            throw new UnauthorizedException(
                { error: 'Access token invalid', code: 'TOKEN_INVALID' },
            );
        }
    }
}
