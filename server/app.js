'use strict';

const express = require('express');
const helmet = require('helmet');
const { pool } = require('./config/database');
const { redis } = require('./config/redis');
const { globalLimiter } = require('./middleware/rateLimiter');

const app = express();

// --- Security & parsing ---
app.use(helmet());
app.use(express.json({ limit: '10kb' }));

// --- Make redis available to routes ---
app.locals.redis = redis;

// --- Make db pool available to routes ---
app.use((req, res, next) => {
  req.pool = pool;
  next();
});

// --- Global rate-limit ---
app.use(globalLimiter);

// --- Health endpoints ---
app.get('/express_status', (req, res) => res.json({ status: 'ok' }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// --- Import routes ---
const authRoute = require('./routes/auth');
const loginRoute = require('./routes/login');
const twoFARoute = require('./routes/2fa_auth');
const placesRoute = require('./routes/places');
const registerRoute = require('./routes/register');
const usersRouter = require('./routes/users');
const currencyRoute = require('./routes/currency');
const authSessionRoute = require('./routes/auth_session');
const verifyClientToken = require('./middleware/verifyClientToken');
const {
  loginLimiter,
  request2faLimiter,
  verify2faLimiter,
  usersLimiter,
} = require('./middleware/rateLimiter');

// --- Apply routes ---
app.use('/auth', authRoute);
app.use('/login', loginLimiter, loginRoute);
app.use('/2fa', verifyClientToken, (req, res, next) => {
  if (req.path === '/request') return request2faLimiter(req, res, next);
  if (req.path === '/verify') return verify2faLimiter(req, res, next);
  next();
}, twoFARoute);
app.use('/places', placesRoute);
app.use('/register', registerRoute);
app.use('/users', verifyClientToken, usersLimiter, usersRouter);
app.use('/auth-session', authSessionRoute);
app.use('/currency', currencyRoute);

module.exports = app;
