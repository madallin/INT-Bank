"use strict";
// ============================================================
// Route: 2FA Auth — Twilio Verify SMS
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const twilio_1 = __importDefault(require("twilio"));
const redis_1 = require("../config/redis");
const router = (0, express_1.Router)();
const twilioClient = (0, twilio_1.default)(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const SERVICE_SID = process.env.TWILIO_SERVICE_SID;
// Helper simplu pentru validare număr de telefon
function requirePhone(phone) {
    return typeof phone === 'string' && phone.length > 4;
}
/**
 * POST /2fa/request
 * Body: { phone, nonce? }
 */
router.post('/request', async (req, res) => {
    const { phone } = req.body;
    if (!phone) {
        res.status(400).json({ error: 'Numar de telefon lipsa' });
        return;
    }
    const lastSentKey = `2fa:last:${phone}`;
    const lastSent = await redis_1.redis.get(lastSentKey);
    if (lastSent && Date.now() - parseInt(lastSent) < 60 * 1000) {
        res.status(429).json({ error: 'Asteapta 1 minut inainte de a retrimite codul' });
        return;
    }
    try {
        await twilioClient.verify.v2.services(SERVICE_SID).verifications.create({
            to: phone,
            channel: 'sms',
        });
        await redis_1.redis.set(lastSentKey, Date.now(), 'EX', 60);
        res.json({ success: true });
    }
    catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Eroare la trimiterea SMS-ului' });
    }
});
/**
 * POST /2fa/verify
 * Body: { phone, code }
 */
router.post('/verify', async (req, res) => {
    const { phone, code } = req.body;
    if (!requirePhone(phone) || !code) {
        res.status(400).json({ error: 'Parametri lipsa' });
        return;
    }
    if (!req.client) {
        res.status(401).json({ error: 'Timpul de verificare a tokenului a expirat.' });
        return;
    }
    try {
        const check = await twilioClient.verify.v2.services(SERVICE_SID).verificationChecks.create({
            to: phone,
            code,
        });
        if (check.status === 'approved') {
            res.json({ success: true, status: check.status });
        }
        else {
            res.status(400).json({ success: false, status: check.status });
        }
    }
    catch (twErr) {
        console.error('Twilio verify error:', twErr);
        if (twErr.code === 60202) {
            res.status(429).json({
                error: 'Ai depasit numarul maxim de incercari pentru codul de verificare. Te rugam sa retrimiti codul.',
            });
            return;
        }
        if (twErr.code === 20404) {
            res.status(400).json({ error: 'Codul de verificare este invalid sau a expirat.' });
            return;
        }
        const msg = (twErr && (twErr.message || (twErr.error && twErr.error.message))) ||
            'Eroare la verificarea codului';
        res.status(500).json({ error: msg });
    }
});
exports.default = router;
//# sourceMappingURL=2fa_auth.js.map