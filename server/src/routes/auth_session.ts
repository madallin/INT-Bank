// ============================================================
// Route: Auth Session — JWT with refresh token rotation
// ============================================================

import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Pool } from 'pg';
import { createAccountAndCard } from '../services/banking';

interface AuthSessionRequest extends Request {
  pool?: Pool;
}

const router = Router();

const SALT_ROUNDS = 12;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY_DAYS = 7;

/**
 * POST /auth-session/login
 * Body: { phone, pin }
 * Returns: { accessToken, refreshToken, userId }
 */
router.post('/login', async (req: AuthSessionRequest, res: Response) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) {
    res.status(400).json({ error: 'Telefon si PIN sunt necesare' });
    return;
  }

  let client;
  try {
    client = await req.pool!.connect();
    const result = await client.query(
      'SELECT id, pincont FROM utilizatori WHERE nrtelefon = $1 AND contaprobat = true',
      [phone],
    );

    if (result.rowCount === 0) {
      res.status(401).json({ error: 'Cont inexistent sau neaprobat' });
      return;
    }

    const user = result.rows[0];

    const pinMatch = await bcrypt.compare(pin, user.pincont);
    if (!pinMatch) {
      res.status(401).json({ error: 'PIN incorect' });
      return;
    }

    const accessToken = jwt.sign({ userId: user.id, role: 'user' }, process.env.JWT_SECRET!, {
      expiresIn: ACCESS_TOKEN_EXPIRY,
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const refreshTokenHash = await bcrypt.hash(refreshToken, SALT_ROUNDS);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    await client.query('DELETE FROM sesiuni WHERE user_id = $1', [user.id]);
    await client.query(
      'INSERT INTO sesiuni (user_id, refresh_token_hash, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshTokenHash, expiresAt],
    );

    const accountCheck = await client.query(
      'SELECT COUNT(*) AS cnt FROM conturiBancare WHERE userid = $1',
      [user.id],
    );
    const hasAccounts = parseInt(accountCheck.rows[0].cnt, 10) > 0;

    if (!hasAccounts) {
      client.release();
      client = null;

      console.log(`Creare automată cont+card pentru user ${user.id}...`);
      await createAccountAndCard(user.id, 'RON', 'RO');
      console.log(`Cont+card creat automat pentru user ${user.id}`);
    }

    res.json({ accessToken, refreshToken, userId: user.id });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Eroare la autentificare' });
  } finally {
    if (client) client.release();
  }
});

/**
 * POST /auth-session/refresh
 * Body: { refreshToken }
 * Returns: { accessToken, refreshToken }
 */
router.post('/refresh', async (req: AuthSessionRequest, res: Response) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(400).json({ error: 'Refresh token lipsa' });
    return;
  }

  let client;
  try {
    client = await req.pool!.connect();

    const result = await client.query(
      'SELECT id, user_id, refresh_token_hash FROM sesiuni WHERE expires_at > NOW() ORDER BY created_at DESC',
    );

    let matchedSession = null;
    for (const row of result.rows) {
      const match = await bcrypt.compare(refreshToken, row.refresh_token_hash);
      if (match) {
        matchedSession = row;
        break;
      }
    }

    if (!matchedSession) {
      res.status(401).json({ error: 'Refresh token invalid sau expirat' });
      return;
    }

    await client.query('DELETE FROM sesiuni WHERE id = $1', [matchedSession.id]);

    const newAccessToken = jwt.sign(
      { userId: matchedSession.user_id, role: 'user' },
      process.env.JWT_SECRET!,
      { expiresIn: ACCESS_TOKEN_EXPIRY },
    );

    const newRefreshToken = crypto.randomBytes(64).toString('hex');
    const newRefreshTokenHash = await bcrypt.hash(newRefreshToken, SALT_ROUNDS);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    await client.query(
      'INSERT INTO sesiuni (user_id, refresh_token_hash, expires_at) VALUES ($1, $2, $3)',
      [matchedSession.user_id, newRefreshTokenHash, expiresAt],
    );

    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (err) {
    console.error('Refresh error:', err);
    res.status(500).json({ error: 'Eroare la reimprospatarea sesiunii' });
  } finally {
    if (client) client.release();
  }
});

/**
 * POST /auth-session/logout
 * Body: { refreshToken }
 */
router.post('/logout', async (req: AuthSessionRequest, res: Response) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(400).json({ error: 'Refresh token lipsa' });
    return;
  }

  let client;
  try {
    client = await req.pool!.connect();

    const result = await client.query('SELECT id, refresh_token_hash FROM sesiuni');

    for (const row of result.rows) {
      const match = await bcrypt.compare(refreshToken, row.refresh_token_hash);
      if (match) {
        await client.query('DELETE FROM sesiuni WHERE id = $1', [row.id]);
        res.json({ success: true });
        return;
      }
    }

    res.json({ success: true });
  } catch (err) {
    console.error('Logout error:', err);
    res.status(500).json({ error: 'Eroare la delogare' });
  } finally {
    if (client) client.release();
  }
});

export default router;
