// ============================================================
// Application Entry: Express App Configuration
// ============================================================

import express, { Application, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import { pool } from './config/database';
import { redis } from './config/redis';
import { globalLimiter } from './middleware/rateLimiter';

import authRoute from './routes/auth';
import loginRoute from './routes/login';
import twoFARoute from './routes/2fa_auth';
import placesRoute from './routes/places';
import registerRoute from './routes/register';
import usersRouter from './routes/users';
import currencyRoute from './routes/currency';
import authSessionRoute from './routes/auth_session';
import verifyClientToken from './middleware/verifyClientToken';
import {
  loginLimiter,
  request2faLimiter,
  verify2faLimiter,
  usersLimiter,
} from './middleware/rateLimiter';

const app: Application = express();

// --- Security & parsing ---
app.use(helmet());
app.use(express.json({ limit: '10kb' }));

// --- Make redis available to routes ---
app.locals.redis = redis;

// --- Make db pool available to routes ---
app.use((req: Request, _res: Response, next: NextFunction) => {
  (req as any).pool = pool;
  next();
});

// --- Global rate-limit ---
app.use(globalLimiter);

// --- Health endpoints ---
app.get('/express_status', (_req: Request, res: Response) => res.json({ status: 'ok' }));
app.get('/health', (_req: Request, res: Response) => res.json({ status: 'ok' }));

// --- Apply routes ---
app.use('/auth', authRoute);
app.use('/login', loginLimiter, loginRoute);
app.use(
  '/2fa',
  verifyClientToken,
  (req: Request, res: Response, next: NextFunction) => {
    if (req.path === '/request') return request2faLimiter(req, res, next);
    if (req.path === '/verify') return verify2faLimiter(req, res, next);
    next();
  },
  twoFARoute,
);
app.use('/places', placesRoute);
app.use('/register', registerRoute);
app.use('/users', verifyClientToken, usersLimiter, usersRouter);
app.use('/auth-session', authSessionRoute);
app.use('/currency', currencyRoute);

export default app;
