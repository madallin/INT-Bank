"use strict";
// ============================================================
// Route: Auth — Client token generation & refresh
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = __importDefault(require("crypto"));
const redis_1 = require("../config/redis");
const router = (0, express_1.Router)();
// POST /auth/get-client-token
router.post('/get-client-token', async (req, res) => {
    const deviceId = req.body.deviceId || 'dev-device';
    try {
        if (!process.env.JWT_SECRET) {
            res.status(500).json({ error: 'JWT secret not configured' });
            return;
        }
        const clientToken = jsonwebtoken_1.default.sign({ deviceId }, process.env.JWT_SECRET, { expiresIn: '5m' });
        const refreshToken = crypto_1.default.randomBytes(32).toString('hex');
        await redis_1.redis.set(`refresh:${deviceId}`, refreshToken, 'EX', 15 * 60);
        res.json({ client_token: clientToken, refresh_token: refreshToken });
    }
    catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error generating token' });
    }
});
// POST /auth/refresh-client-token
router.post('/refresh-client-token', async (req, res) => {
    const { deviceId, refreshToken } = req.body;
    if (!deviceId || !refreshToken) {
        res.status(400).json({ error: 'Missing parameters' });
        return;
    }
    try {
        const stored = await redis_1.redis.get(`refresh:${deviceId}`);
        if (!stored || stored !== refreshToken) {
            res.status(401).json({ error: 'Invalid or expired refresh token' });
            return;
        }
        const newToken = jsonwebtoken_1.default.sign({ deviceId }, process.env.JWT_SECRET, { expiresIn: '5m' });
        res.json({ client_token: newToken, ttl: 300 });
    }
    catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});
exports.default = router;
//# sourceMappingURL=auth.js.map