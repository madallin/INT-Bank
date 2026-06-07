'use strict';

const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const {
  LOGIN_WINDOW_MS,
  LOGIN_MAX_ATTEMPTS,
  TWOFA_REQUEST_MAX,
  TWOFA_VERIFY_MAX,
  TWOFA_VERIFY_WINDOW_MS,
  USERS_WINDOW_MS,
  USERS_MAX_REQUESTS,
  GLOBAL_WINDOW_MS,
  GLOBAL_MAX_REQUESTS,
} = require('../config/constants');

/**
 * Key generator: uses phone from body, falls back to IP.
 */
const phoneOrIpKey = (req) => {
  if (req.body && req.body.phone) return `phone:${req.body.phone}`;
  return `ip:${ipKeyGenerator(req)}`;
};

// --- Global rate-limit ---
const globalLimiter = rateLimit({
  windowMs: GLOBAL_WINDOW_MS,
  max: GLOBAL_MAX_REQUESTS,
  message: { error: 'Prea multe cereri trimise intr-un timp scurt' },
  standardHeaders: true,
  legacyHeaders: false,
});

// --- Rate-limit per login ---
const loginLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: LOGIN_MAX_ATTEMPTS,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) => res.status(429).json({ error: 'Prea multe încercări pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
});

// --- Rate-limit per 2FA request ---
const request2faLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: TWOFA_REQUEST_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) => res.status(429).json({ error: 'Prea multe cereri pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
});

// --- Rate-limit per 2FA verify ---
const verify2faLimiter = rateLimit({
  windowMs: TWOFA_VERIFY_WINDOW_MS,
  max: TWOFA_VERIFY_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) => res.status(429).json({ error: 'Prea multe încercări de verificare. Încearcă din nou mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
});

// --- Rate-limit per users endpoints ---
const usersLimiter = rateLimit({
  windowMs: USERS_WINDOW_MS,
  max: USERS_MAX_REQUESTS,
  message: { error: 'Prea multe cereri. Încearcă mai târziu.' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    if (req.user && req.user.id) return `user:${req.user.id}`;
    return `ip:${ipKeyGenerator(req)}`;
  },
});

module.exports = {
  globalLimiter,
  loginLimiter,
  request2faLimiter,
  verify2faLimiter,
  usersLimiter,
};
