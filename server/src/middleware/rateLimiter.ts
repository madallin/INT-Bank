import rateLimit from 'express-rate-limit';
import type { Request } from 'express';
import {
  LOGIN_WINDOW_MS,
  LOGIN_MAX_ATTEMPTS,
  TWOFA_REQUEST_MAX,
  TWOFA_VERIFY_MAX,
  TWOFA_VERIFY_WINDOW_MS,
  USERS_WINDOW_MS,
  USERS_MAX_REQUESTS,
  GLOBAL_WINDOW_MS,
  GLOBAL_MAX_REQUESTS,
} from '../config/constants';

// keyGenerator prefixes with ip:/phone:/user: and has fallback chain;
// disable express-rate-limit's built-in IP validation to avoid false IPv6 warnings.
const phoneOrIpKey = (req: Request): string =>
{
  if(req.body && req.body.phone) return `phone:${req.body.phone}`;
  return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
};

const globalLimiter = rateLimit({
  windowMs: GLOBAL_WINDOW_MS,
  max: GLOBAL_MAX_REQUESTS,
  message: { error: 'Prea multe cereri trimise intr-un timp scurt' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
});

const loginLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: LOGIN_MAX_ATTEMPTS,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe încercări pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
});

const request2faLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: TWOFA_REQUEST_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe cereri pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
});

const verify2faLimiter = rateLimit({
  windowMs: TWOFA_VERIFY_WINDOW_MS,
  max: TWOFA_VERIFY_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe încercări de verificare. Încearcă din nou mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
});

const usersLimiter = rateLimit({
  windowMs: USERS_WINDOW_MS,
  max: USERS_MAX_REQUESTS,
  message: { error: 'Prea multe cereri. Încearcă mai târziu.' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) =>
  {
    if((req as any).user?.id) return `user:${(req as any).user.id}`;
    return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
  },
  validate: false,
});

export {
  globalLimiter,
  loginLimiter,
  request2faLimiter,
  verify2faLimiter,
  usersLimiter,
};
