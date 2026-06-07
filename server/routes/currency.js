// routes/currency.js
const express = require('express');
const router = express.Router();
const axios = require('axios');

// GET /currency/:code
router.get('/:code', async (req, res) => {
  const { code } = req.params;
  const base = code?.toLowerCase();

  if (!base || base.length !== 3) {
    return res.status(400).json({ error: 'Cod valutar invalid (ex: eur, usd, ron)' });
  }

  const primaryUrl = `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${base}.json`;
  const fallbackUrl = `https://latest.currency-api.pages.dev/v1/currencies/${base}.json`;

  try {
    // Încearcă să iei datele de la jsDelivr
    const response = await axios.get(primaryUrl, { timeout: 5000 });
    return res.json({
      success: true,
      source: 'jsdelivr',
      data: response.data,
    });
  } catch (err1) {
    console.warn(`Primary API failed (${primaryUrl}), trying fallback...`);

    try {
      // Încearcă fallback Cloudflare
      const fallbackResponse = await axios.get(fallbackUrl, { timeout: 5000 });
      return res.json({
        success: true,
        source: 'cloudflare',
        data: fallbackResponse.data,
      });
    } catch (err2) {
      console.error('Eroare la preluarea cursurilor valutare:', err2);
      return res.status(500).json({
        error: 'Nu s-au putut prelua datele valutare din niciun server.',
      });
    }
  }
});

module.exports = router;
