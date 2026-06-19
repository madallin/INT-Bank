// routes/currency.js
const express = require('express');
const router = express.Router();
const axios = require('axios');

const FRANKFURTER_API = 'https://api.frankfurter.dev/v2';
const COMMISSION_PERCENT = 1.5;
const CACHE_TTL_SECONDS = 3600; // 1 oră
const CACHE_KEY = 'banking:rates';

/**
 * GET /api/v1/exchange-rates
 * Returnează cursurile EUR/USD/GBP raportate la RON.
 * Folosește Redis cache (TTL 1h) pentru a nu abuza de Frankfurter API.
 */
router.get('/api/v1/exchange-rates', async (req, res) => {
  const redis = req.app?.locals?.redis;

  if (!redis) {
    return res.status(500).json({ error: 'Redis not available' });
  }

  try {
    // ── CASE A: Cache hit ──
    const cached = await redis.get(CACHE_KEY);
    if (cached) {
      const parsed = JSON.parse(cached);
      return res.json(parsed);
    }

    // ── CASE B: Cache miss — fetch from Frankfurter ──
    const url = `${FRANKFURTER_API}/rates?base=RON&quotes=EUR,USD,GBP`;
    const response = await axios.get(url, { timeout: 10000 });
    const data = response.data;

    if (!Array.isArray(data) || data.length === 0) {
      return res.status(502).json({ error: 'Invalid response from Frankfurter API' });
    }

    // Frankfurter v2 returns an array of { date, base, quote, rate }
    const rates = {};
    for (const entry of data) {
      rates[entry.quote] = entry.rate;
    }

    const payload = {
      base: 'RON',
      date: data[0].date,
      rates,
      commissionPercent: COMMISSION_PERCENT,
      last_cached: new Date().toISOString(),
    };

    // Salvează în Redis cu TTL de 1 oră
    await redis.setex(CACHE_KEY, CACHE_TTL_SECONDS, JSON.stringify(payload));

    return res.json(payload);
  } catch (err) {
    console.error('Error fetching exchange rates:', err.message);
    return res.status(502).json({ error: 'Failed to fetch exchange rates' });
  }
});

// Keep the old routes for backward compatibility
router.post('/rate', async (req, res) => {
  try {
    const { base, quote, amount } = req.body;
    if (!base || !quote) {
      return res.status(400).json({ error: 'base and quote are required' });
    }

    const baseCode = base.toUpperCase();
    const quoteCode = quote.toUpperCase();
    const url = `${FRANKFURTER_API}/rate/${baseCode}/${quoteCode}`;
    const response = await axios.get(url, { timeout: 8000 });
    const data = response.data;

    if (!data || typeof data.rate !== 'number') {
      return res.status(502).json({ error: 'Invalid response from exchange rate API' });
    }

    const originalRate = data.rate;
    const rateWithCommission = originalRate * (1 - COMMISSION_PERCENT / 100);
    const parsedAmount = parseFloat(amount) || 1;
    const commissionAmount = parseFloat((parsedAmount * originalRate * (COMMISSION_PERCENT / 100)).toFixed(2));
    const result = parseFloat((parsedAmount * rateWithCommission).toFixed(2));

    return res.json({
      success: true,
      base: baseCode,
      quote: quoteCode,
      originalRate,
      rate: parseFloat(rateWithCommission.toFixed(6)),
      commissionPercent: COMMISSION_PERCENT,
      commissionAmount,
      amount: parsedAmount,
      result,
    });
  } catch (err) {
    console.error('Error fetching exchange rate:', err.message);
    if (err.response?.status === 404) {
      return res.status(404).json({ error: 'Currency pair not found or not supported' });
    }
    return res.status(502).json({ error: 'Failed to fetch exchange rate' });
  }
});

router.get('/rate/:base/:quote', async (req, res) => {
  try {
    const { base, quote } = req.params;
    const url = `${FRANKFURTER_API}/rate/${base.toUpperCase()}/${quote.toUpperCase()}`;
    const response = await axios.get(url, { timeout: 8000 });
    return res.json(response.data);
  } catch (err) {
    return res.status(502).json({ error: 'Failed to fetch exchange rate' });
  }
});

router.get('/:code', async (req, res) => {
  const { code } = req.params;
  const base = code?.toLowerCase();
  if (!base || base.length !== 3) {
    return res.status(400).json({ error: 'Cod valutar invalid (ex: eur, usd, ron)' });
  }

  const primaryUrl = `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${base}.json`;
  const fallbackUrl = `https://latest.currency-api.pages.dev/v1/currencies/${base}.json`;

  try {
    const response = await axios.get(primaryUrl, { timeout: 5000 });
    return res.json({ success: true, source: 'jsdelivr', data: response.data });
  } catch (err1) {
    console.warn(`Primary API failed, trying fallback...`);
    try {
      const fallbackResponse = await axios.get(fallbackUrl, { timeout: 5000 });
      return res.json({ success: true, source: 'cloudflare', data: fallbackResponse.data });
    } catch (err2) {
      console.error('Eroare la preluarea cursurilor valutare:', err2);
      return res.status(500).json({ error: 'Nu s-au putut prelua datele valutare din niciun server.' });
    }
  }
});

module.exports = router;
