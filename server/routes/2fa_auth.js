const express = require('express');
const router = express.Router();
const twilio = require('twilio');

const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const SERVICE_SID = process.env.TWILIO_SERVICE_SID;

// Helper simplu pentru validare număr de telefon
function requirePhone(phone) {
  return typeof phone === 'string' && phone.length > 4;
}

/**
 * POST /2fa/request
 * Body: { phone, nonce? }
 * JWT-ul clientului trebuie să fie valid (verifyClientToken middleware)
 */
router.post('/request', async (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'Numar de telefon lipsa' });

  const redis = req.app.locals.redis;
  const lastSentKey = `2fa:last:${phone}`;
  const lastSent = await redis.get(lastSentKey);

  if (lastSent && Date.now() - parseInt(lastSent) < 60 * 1000) {
    return res.status(429).json({ error: 'Asteapta 1 minut inainte de a retrimite codul' });
  }

  try {
    await client.verify.v2.services(SERVICE_SID)
      .verifications.create({ to: phone, channel: 'sms' });

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
router.post('/verify', async (req, res) => {
  const { phone, code } = req.body;
  if (!requirePhone(phone) || !code) return res.status(400).json({ error: 'Parametri lipsa' });
  if (!req.client) return res.status(401).json({ error: 'Timpul de verificare a tokenului a expirat.' });

  try {
    const check = await client.verify.v2
      .services(SERVICE_SID)
      .verificationChecks.create({ to: phone, code });

    if (check.status === 'approved') {
      return res.json({ success: true, status: check.status });
    } else {
      return res.status(400).json({ success: false, status: check.status });
    }
  } catch (twErr) {
    console.error('Twilio verify error:', twErr);

    // verificăm codul Twilio
    if (twErr.code === 60202) {
      // Max check attempts reached
      return res.status(429).json({
        error: 'Ai depasit numarul maxim de incercari pentru codul de verificare. Te rugam sa retrimiti codul.'
      });
    }

    if (twErr.code === 20404) {
      // Code invalid sau nu exista verificarea
      return res.status(400).json({ error: 'Codul de verificare este invalid sau a expirat.' });
    }

    // fallback generic
    const msg = (twErr && (twErr.message || (twErr.error && twErr.error.message))) || 'Eroare la verificarea codului';
    return res.status(500).json({ error: msg });
  }
});

module.exports = router;
