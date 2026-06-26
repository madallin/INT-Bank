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

const phoneOrIpKey = (req: Request): string =>
{
  if(req.body && req.body.phone) return `phone:${req.body.phone}`;
  // IPv6-safe; express-rate-limit skips internal IP validation
  return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
};

// express-rate-limit v7+ validates internal key format;
// disable its IP heuristic so our keyGenerator works with any IP shape.
const validationOpts = { xForwardedForHeader: false } as const;

const globalLimiter = rateLimit({
  windowMs: GLOBAL_WINDOW_MS,
  max: GLOBAL_MAX_REQUESTS,
  message: { error: 'Prea multe cereri trimise intr-un timp scurt' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: validationOpts,
});

const loginLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: LOGIN_MAX_ATTEMPTS,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe încercări pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: validationOpts,
});

const request2faLimiter = rateLimit({
  windowMs: LOGIN_WINDOW_MS,
  max: TWOFA_REQUEST_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe cereri pentru acest număr. Încearcă mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: validationOpts,
});

const verify2faLimiter = rateLimit({
  windowMs: TWOFA_VERIFY_WINDOW_MS,
  max: TWOFA_VERIFY_MAX,
  keyGenerator: phoneOrIpKey,
  handler: (req, res) =>
    res.status(429).json({ error: 'Prea multe încercări de verificare. Încearcă din nou mai târziu.' }),
  standardHeaders: true,
  legacyHeaders: false,
  validate: validationOpts,
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
  validate: validationOpts,
});

export {
  globalLimiter,
  loginLimiter,
  request2faLimiter,
  verify2faLimiter,
  usersLimiter,
};
