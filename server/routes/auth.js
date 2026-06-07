'use strict';

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { redis } = require('../config/redis');

// POST /auth/get-client-token
router.post('/get-client-token', async (req, res) => {
  const deviceId = req.body.deviceId || 'dev-device';
  try {
    if (!process.env.JWT_SECRET) return res.status(500).json({ error: 'JWT secret not configured' });

    const clientToken = jwt.sign({ deviceId }, process.env.JWT_SECRET, { expiresIn: '5m' });
    const refreshToken = crypto.randomBytes(32).toString('hex');

    await redis.set(`refresh:${deviceId}`, refreshToken, 'EX', 15 * 60);

    res.json({ client_token: clientToken, refresh_token: refreshToken });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error generating token' });
  }
});

// POST /auth/refresh-client-token
router.post('/refresh-client-token', async (req, res) => {
  const { deviceId, refreshToken } = req.body;
  if (!deviceId || !refreshToken) return res.status(400).json({ error: 'Missing parameters' });

  try {
    const stored = await redis.get(`refresh:${deviceId}`);
    if (!stored || stored !== refreshToken) return res.status(401).json({ error: 'Invalid or expired refresh token' });

    const newToken = jwt.sign({ deviceId }, process.env.JWT_SECRET, { expiresIn: '5m' });
    res.json({ client_token: newToken, ttl: 300 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
