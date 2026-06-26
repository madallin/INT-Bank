import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface ClientPayload
{
  deviceId: string;
  iat?: number;
  exp?: number;
}

export interface ClientTokenRequest extends Request
{
  client?: ClientPayload;
}

function verifyClientToken(req: ClientTokenRequest, res: Response, next: NextFunction): void
{
  const auth = req.headers.authorization;
  if(!auth || !auth.startsWith('Bearer '))
  {
    res.status(401).json({ error: 'Missing client token', code: 'NO_TOKEN' });
    return;
  }

  const token = auth.slice(7);

  try
  {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as ClientPayload;
    req.client = payload;
    next();
  }
  catch (err: any)
  {
    if(err.name === 'TokenExpiredError')
    {
      res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
      return;
    }
    res.status(401).json({ error: 'Token invalid', code: 'TOKEN_INVALID' });
  }
}

export default verifyClientToken;
