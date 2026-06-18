// routes/auth_session.js
// Autentificare JWT cu refresh token rotation

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const SALT_ROUNDS = 12;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY_DAYS = 7;

/**
 * POST /auth-session/login
 * Body: { phone, pin }
 * Returns: { accessToken, refreshToken, userId }
 */
router.post('/login', async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) {
    return res.status(400).json({ error: 'Telefon si PIN sunt necesare' });
  }

  let client;
  try {
    client = await req.pool.connect();
    const result = await client.query(
      'SELECT id, pincont FROM utilizatori WHERE nrtelefon = $1 AND contaprobat = true',
      [phone]
    );

    if (result.rowCount === 0) {
      return res.status(401).json({ error: 'Cont inexistent sau neaprobat' });
    }

    const user = result.rows[0];

    // Verifică PIN-ul
    const pinMatch = await bcrypt.compare(pin, user.pincont);
    if (!pinMatch) {
      return res.status(401).json({ error: 'PIN incorect' });
    }

    // Generează accessToken
    const accessToken = jwt.sign(
      { userId: user.id, role: 'user' },
      process.env.JWT_SECRET,
      { expiresIn: ACCESS_TOKEN_EXPIRY }
    );

    // Generează refreshToken
    const refreshToken = crypto.randomBytes(64).toString('hex');
    const refreshTokenHash = await bcrypt.hash(refreshToken, SALT_ROUNDS);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    // Salvează sesiunea în DB
    await client.query(
      'INSERT INTO sesiuni (user_id, refresh_token_hash, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshTokenHash, expiresAt]
    );

    return res.json({ accessToken, refreshToken, userId: user.id });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'Eroare la autentificare' });
  } finally {
    if (client) client.release();
  }
});

/**
 * POST /auth-session/refresh
 * Body: { refreshToken }
 * Returns: { accessToken, refreshToken }
 * Rotation: invalidates old token, creates new one
 */
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token lipsa' });
  }

  let client;
  try {
    client = await req.pool.connect();

    // Găsește toate sesiunile neexpirate
    const result = await client.query(
      'SELECT id, user_id, refresh_token_hash FROM sesiuni WHERE expires_at > NOW() ORDER BY created_at DESC'
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
      return res.status(401).json({ error: 'Refresh token invalid sau expirat' });
    }

    // Token rotation: șterge sesiunea veche
    await client.query('DELETE FROM sesiuni WHERE id = $1', [matchedSession.id]);

    // Generează tokeni noi
    const newAccessToken = jwt.sign(
      { userId: matchedSession.user_id, role: 'user' },
      process.env.JWT_SECRET,
      { expiresIn: ACCESS_TOKEN_EXPIRY }
    );

    const newRefreshToken = crypto.randomBytes(64).toString('hex');
    const newRefreshTokenHash = await bcrypt.hash(newRefreshToken, SALT_ROUNDS);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    // Salvează noua sesiune
    await client.query(
      'INSERT INTO sesiuni (user_id, refresh_token_hash, expires_at) VALUES ($1, $2, $3)',
      [matchedSession.user_id, newRefreshTokenHash, expiresAt]
    );

    return res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (err) {
    console.error('Refresh error:', err);
    return res.status(500).json({ error: 'Eroare la reimprospatarea sesiunii' });
  } finally {
    if (client) client.release();
  }
});

/**
 * POST /auth-session/logout
 * Body: { refreshToken }
 * Invalidates the session
 */
router.post('/logout', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token lipsa' });
  }

  let client;
  try {
    client = await req.pool.connect();

    // Găsește și șterge sesiunea
    const result = await client.query(
      'SELECT id, refresh_token_hash FROM sesiuni'
    );

    for (const row of result.rows) {
      const match = await bcrypt.compare(refreshToken, row.refresh_token_hash);
      if (match) {
        await client.query('DELETE FROM sesiuni WHERE id = $1', [row.id]);
        return res.json({ success: true });
      }
    }

    return res.json({ success: true }); // Chiár dacă nu găsim, returnăm succes
  } catch (err) {
    console.error('Logout error:', err);
    return res.status(500).json({ error: 'Eroare la delogare' });
  } finally {
    if (client) client.release();
  }
});

module.exports = router;
