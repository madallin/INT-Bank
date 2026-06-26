"use strict";
// ============================================================
// Application Entry: Express App Configuration
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const helmet_1 = __importDefault(require("helmet"));
const database_1 = require("./config/database");
const redis_1 = require("./config/redis");
const rateLimiter_1 = require("./middleware/rateLimiter");
const auth_1 = __importDefault(require("./routes/auth"));
const login_1 = __importDefault(require("./routes/login"));
const _2fa_auth_1 = __importDefault(require("./routes/2fa_auth"));
const places_1 = __importDefault(require("./routes/places"));
const register_1 = __importDefault(require("./routes/register"));
const users_1 = __importDefault(require("./routes/users"));
const currency_1 = __importDefault(require("./routes/currency"));
const auth_session_1 = __importDefault(require("./routes/auth_session"));
const verifyClientToken_1 = __importDefault(require("./middleware/verifyClientToken"));
const rateLimiter_2 = require("./middleware/rateLimiter");
const app = (0, express_1.default)();
// --- Security & parsing ---
app.use((0, helmet_1.default)());
app.use(express_1.default.json({ limit: '10kb' }));
// --- Make redis available to routes ---
app.locals.redis = redis_1.redis;
// --- Make db pool available to routes ---
app.use((req, _res, next) => {
    req.pool = database_1.pool;
    next();
});
// --- Global rate-limit ---
app.use(rateLimiter_1.globalLimiter);
// --- Health endpoints ---
app.get('/express_status', (_req, res) => res.json({ status: 'ok' }));
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
// --- Apply routes ---
app.use('/auth', auth_1.default);
app.use('/login', rateLimiter_2.loginLimiter, login_1.default);
app.use('/2fa', verifyClientToken_1.default, (req, res, next) => {
    if (req.path === '/request') {
        (0, rateLimiter_2.request2faLimiter)(req, res, next);
        return;
    }
    if (req.path === '/verify') {
        (0, rateLimiter_2.verify2faLimiter)(req, res, next);
        return;
    }
    next();
}, _2fa_auth_1.default);
app.use('/places', places_1.default);
app.use('/register', register_1.default);
app.use('/users', verifyClientToken_1.default, rateLimiter_2.usersLimiter, users_1.default);
app.use('/auth-session', auth_session_1.default);
app.use('/currency', currency_1.default);
exports.default = app;
//# sourceMappingURL=app.js.map