"use strict";
// ============================================================
// Rate Limit Middleware — Express
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.usersLimiter = exports.verify2faLimiter = exports.request2faLimiter = exports.loginLimiter = exports.globalLimiter = void 0;
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const constants_1 = require("../config/constants");
/**
 * Key generator: uses phone from body, falls back to IP.
 */
const phoneOrIpKey = (req) => {
    if (req.body && req.body.phone)
        return `phone:${req.body.phone}`;
    return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
};
// --- Global rate-limit ---
const globalLimiter = (0, express_rate_limit_1.default)({
    windowMs: constants_1.GLOBAL_WINDOW_MS,
    max: constants_1.GLOBAL_MAX_REQUESTS,
    message: { error: 'Prea multe cereri trimise intr-un timp scurt' },
    standardHeaders: true,
    legacyHeaders: false,
});
exports.globalLimiter = globalLimiter;
// --- Rate-limit per login ---
const loginLimiter = (0, express_rate_limit_1.default)({
    windowMs: constants_1.LOGIN_WINDOW_MS,
    max: constants_1.LOGIN_MAX_ATTEMPTS,
    keyGenerator: phoneOrIpKey,
    handler: (req, res) => res.status(429).json({ error: 'Prea multe încercări pentru acest număr. Încearcă mai târziu.' }),
    standardHeaders: true,
    legacyHeaders: false,
});
exports.loginLimiter = loginLimiter;
// --- Rate-limit per 2FA request ---
const request2faLimiter = (0, express_rate_limit_1.default)({
    windowMs: constants_1.LOGIN_WINDOW_MS,
    max: constants_1.TWOFA_REQUEST_MAX,
    keyGenerator: phoneOrIpKey,
    handler: (req, res) => res.status(429).json({ error: 'Prea multe cereri pentru acest număr. Încearcă mai târziu.' }),
    standardHeaders: true,
    legacyHeaders: false,
});
exports.request2faLimiter = request2faLimiter;
// --- Rate-limit per 2FA verify ---
const verify2faLimiter = (0, express_rate_limit_1.default)({
    windowMs: constants_1.TWOFA_VERIFY_WINDOW_MS,
    max: constants_1.TWOFA_VERIFY_MAX,
    keyGenerator: phoneOrIpKey,
    handler: (req, res) => res.status(429).json({ error: 'Prea multe încercări de verificare. Încearcă din nou mai târziu.' }),
    standardHeaders: true,
    legacyHeaders: false,
});
exports.verify2faLimiter = verify2faLimiter;
// --- Rate-limit per users endpoints ---
const usersLimiter = (0, express_rate_limit_1.default)({
    windowMs: constants_1.USERS_WINDOW_MS,
    max: constants_1.USERS_MAX_REQUESTS,
    message: { error: 'Prea multe cereri. Încearcă mai târziu.' },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => {
        if (req.user?.id)
            return `user:${req.user.id}`;
        return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
    },
});
exports.usersLimiter = usersLimiter;
//# sourceMappingURL=rateLimiter.js.map