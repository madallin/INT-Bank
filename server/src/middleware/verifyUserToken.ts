import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface UserPayload
{
  userId: number;
  role?: string;
  iat?: number;
  exp?: number;
}

export interface UserTokenRequest extends Request
{
  userId?: number;
  userRole?: string;
}

function verifyUserToken(req: UserTokenRequest, res: Response, next: NextFunction): void
{
  const auth = req.headers.authorization;
  if(!auth || !auth.startsWith('Bearer '))
  {
    res.status(401).json({ error: 'Missing access token', code: 'NO_TOKEN' });
    return;
  }

  const token = auth.slice(7);

  try
  {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as UserPayload;
    req.userId = payload.userId;
    req.userRole = payload.role || 'user';
    next();
  }
  catch (err: any)
  {
    if(err.name === 'TokenExpiredError')
    {
      res.status(401).json({ error: 'Access token expired', code: 'TOKEN_EXPIRED' });
      return;
    }
    res.status(401).json({ error: 'Access token invalid', code: 'TOKEN_INVALID' });
  }
}

export default verifyUserToken;
