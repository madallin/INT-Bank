import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { redis } from '../config/redis';

const router = Router();

router.post('/get-client-token', async (req: Request, res: Response) =>
{
  const deviceId = req.body.deviceId || 'dev-device';
  try
  {
    if(!process.env.JWT_SECRET)
    {
      res.status(500).json({ error: 'JWT secret not configured' });
      return;
    }

    const clientToken = jwt.sign({ deviceId }, process.env.JWT_SECRET, { expiresIn: '5m' });
    const refreshToken = crypto.randomBytes(32).toString('hex');

    await redis.set(`refresh:${deviceId}`, refreshToken, 'EX', 15 * 60);

    res.json({ client_token: clientToken, refresh_token: refreshToken });
  }
  catch (err)
  {
    console.error(err);
    res.status(500).json({ error: 'Server error generating token' });
  }
});

router.post('/refresh-client-token', async (req: Request, res: Response) =>
{
  const { deviceId, refreshToken } = req.body;
  if(!deviceId || !refreshToken)
  {
    res.status(400).json({ error: 'Missing parameters' });
    return;
  }

  try
  {
    const stored = await redis.get(`refresh:${deviceId}`);
    if(!stored || stored !== refreshToken)
    {
      res.status(401).json({ error: 'Invalid or expired refresh token' });
      return;
    }

    const newToken = jwt.sign({ deviceId }, process.env.JWT_SECRET!, { expiresIn: '5m' });
    res.json({ client_token: newToken, ttl: 300 });
  }
  catch (err)
  {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

export default router;
