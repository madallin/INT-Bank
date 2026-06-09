// routes/places.js
// Geoapify Address Autocomplete API proxy — autocomplete + place details

const express = require('express');
const router = express.Router();
const axios = require('axios');

const GEOAPIFY_BASE = 'https://api.geoapify.com/v1/geocode';

/**
 * GET /places/autocomplete?text=...&locality=...
 * Proxy către Geoapify Address Autocomplete API.
 * Returnează sugestii de adrese cu place_id.
 */
router.get('/autocomplete', async (req, res) => {
  const { text, locality } = req.query;
  if (!text) return res.status(400).json({ error: 'Missing text query' });

  const apiKey = process.env.GEOAPIFY_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Geoapify API key not configured' });

  try {
    // Construim parametri pentru Geoapify Autocomplete
    const params = {
      text,
      type: 'street',
      format: 'json',
      lang: 'ro',
      apiKey,
      filter: 'countrycode:ro',
    };

    // Dacă avem localitatea, o concatenăm în text pentru sugestii mai precise
    if (locality) {
      params.text = `${text}, ${locality}`;
    }

    const geoapifyRes = await axios.get(
      `${GEOAPIFY_BASE}/autocomplete`,
      { params }
    );

    const results = geoapifyRes.data?.results || [];

    // Mapăm răspunsul Geoapify la formatul pe care îl așteaptă Flutter
    const predictions = results.map((r) => ({
      place_id: r.place_id,
      // description = strada (+ număr, dacă există) + cod poștal în paranteză pentru diferențiere
      // (ex: "Aleea Oțelarilor (600302)" sau "Strada X, Nr. 5 (123456)")
      description: (() => {
        const streetPart = r.street
          ? [r.street, r.housenumber].filter(Boolean).join(', ')
          : (r.address_line1 || r.formatted || '').split(',')[0]?.trim() || '';
        const postcode = r.postcode ? ` (${r.postcode})` : '';
        return streetPart + postcode || r.formatted || '';
      })(),

      structured_formatting: {
        main_text: r.street || r.city || r.name || '',
        secondary_text: r.address_line2 || r.formatted?.split(',').slice(1).join(',') || '',
      },
      terms: [
        ...(r.street ? [{ value: r.street }] : []),
        ...(r.housenumber ? [{ value: r.housenumber }] : []),
        ...(r.city ? [{ value: r.city }] : []),
        ...(r.state ? [{ value: r.state }] : []),
        ...(r.country ? [{ value: r.country }] : []),
      ],
    }));

    return res.json({ predictions });
  } catch (err) {
    console.error('Eroare la Geoapify autocomplete:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Error fetching from Geoapify' });
  }
});

/**
 * GET /places/details?place_id=...
 * Proxy către Geoapify Geocoding Search API (by place_id).
 * Returnează adresa structurată (stradă, număr, localitate, județ, cod poștal).
 */
router.get('/details', async (req, res) => {
  const { place_id } = req.query;
  if (!place_id) return res.status(400).json({ error: 'Missing place_id query' });

  const apiKey = process.env.GEOAPIFY_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Geoapify API key not configured' });

  try {
    const geoapifyRes = await axios.get(
      `${GEOAPIFY_BASE}/search`,
      {
        params: {
          id: place_id,
          format: 'json',
          lang: 'ro',
          apiKey,
        },
      }
    );

    const results = geoapifyRes.data?.results || [];
    if (results.length === 0) {
      return res.status(404).json({ error: 'Place not found' });
    }

    const result = results[0];

    // Mapăm răspunsul Geoapify la formatul existent (stradă, număr, etc.)
    const address = {
      place_id,
      formatted_address: result.formatted || '',
      strada: result.street || result.address_line1?.split(',')[0]?.trim() || '',
      numar: result.housenumber || '',
      localitate: result.city || result.county || '',
      judet: result.state || '',
      codPostal: result.postcode || '',
      tara: result.country || '',
      lat: result.lat || null,
      lng: result.lon || null,
    };

    return res.json({ address });
  } catch (err) {
    console.error('Eroare la Geoapify details:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Error fetching place details from Geoapify' });
  }
});

/**
 * GET /places/reverse?lat=...&lon=...
 * Proxy către Geoapify Reverse Geocoding API.
 * Primește coordonate GPS și returnează adresa structurată.
 */
router.get('/reverse', async (req, res) => {
  const { lat, lon } = req.query;
  if (!lat || !lon) return res.status(400).json({ error: 'Missing lat/lon query' });

  const apiKey = process.env.GEOAPIFY_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Geoapify API key not configured' });

  try {
    const geoapifyRes = await axios.get(
      `${GEOAPIFY_BASE}/reverse`,
      {
        params: {
          lat,
          lon,
          format: 'json',
          lang: 'ro',
          limit: 1,
          apiKey,
        },
      }
    );

    const results = geoapifyRes.data?.results || [];
    if (results.length === 0) {
      return res.status(404).json({ error: 'No address found for these coordinates' });
    }

    const result = results[0];

    const address = {
      place_id: result.place_id || '',
      formatted_address: result.formatted || '',
      strada: result.street || result.address_line1?.split(',')[0]?.trim() || '',
      numar: result.housenumber || '',
      localitate: result.city || result.county || '',
      judet: result.state || '',
      codPostal: result.postcode || '',
      tara: result.country || '',
      lat: result.lat || null,
      lng: result.lon || null,
    };

    return res.json({ address });
  } catch (err) {
    console.error('Eroare la Geoapify reverse:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Error fetching reverse geocode from Geoapify' });
  }
});

module.exports = router;


