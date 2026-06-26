// ============================================================
// Route: 2FA Auth — Twilio Verify SMS
// ============================================================

import { Router, Request, Response } from 'express';
import twilio from 'twilio';
import { redis } from '../config/redis';
import { ClientTokenRequest } from '../middleware/verifyClientToken';

const router = Router();
const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID!, process.env.TWILIO_AUTH_TOKEN!);
const SERVICE_SID = process.env.TWILIO_SERVICE_SID!;

interface TwoFARequest extends ClientTokenRequest {
  body: {
    phone?: string;
    code?: string;
    nonce?: string;
  };
}

// Helper simplu pentru validare număr de telefon
function requirePhone(phone: unknown): phone is string {
  return typeof phone === 'string' && phone.length > 4;
}

/**
 * POST /2fa/request
 * Body: { phone, nonce? }
 */
router.post('/request', async (req: TwoFARequest, res: Response) => {
  const { phone } = req.body;
  if (!phone) {
    res.status(400).json({ error: 'Numar de telefon lipsa' });
    return;
  }

  const lastSentKey = `2fa:last:${phone}`;
  const lastSent = await redis.get(lastSentKey);

  if (lastSent && Date.now() - parseInt(lastSent) < 60 * 1000) {
    res.status(429).json({ error: 'Asteapta 1 minut inainte de a retrimite codul' });
    return;
  }

  try {
    await twilioClient.verify.v2.services(SERVICE_SID).verifications.create({
      to: phone,
      channel: 'sms',
    });

    await redis.set(lastSentKey, Date.now(), 'EX', 60);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Eroare la trimiterea SMS-ului' });
  }
});

/**
 * POST /2fa/verify
 * Body: { phone, code }
 */
router.post('/verify', async (req: TwoFARequest, res: Response) => {
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
    } else {
      res.status(400).json({ success: false, status: check.status });
    }
  } catch (twErr: any) {
    console.error('Twilio verify error:', twErr);

    if (twErr.code === 60202) {
      res.status(429).json({
        error:
          'Ai depasit numarul maxim de incercari pentru codul de verificare. Te rugam sa retrimiti codul.',
      });
      return;
    }

    if (twErr.code === 20404) {
      res.status(400).json({ error: 'Codul de verificare este invalid sau a expirat.' });
      return;
    }

    const msg =
      (twErr && (twErr.message || (twErr.error && twErr.error.message))) ||
      'Eroare la verificarea codului';
    res.status(500).json({ error: msg });
  }
});

export default router;
