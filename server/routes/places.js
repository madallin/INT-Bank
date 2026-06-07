// routes/places.js
// Google Places API proxy — autocomplete + place details

const express = require('express');
const router = express.Router();
const axios = require('axios');

/**
 * GET /places/autocomplete?text=...&locality=...
 * Proxy către Google Places Autocomplete API.
 * Returnează sugestii de adrese cu place_id.
 */
router.get('/autocomplete', async (req, res) => {
  const { text, locality } = req.query;
  if (!text) return res.status(400).json({ error: 'Missing text query' });

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Google Maps API key not configured' });

  try {
    const params = {
      input: text,
      types: 'address',
      language: 'ro',
      components: 'country:ro',
      key: apiKey,
    };

    // Dacă avem localitatea, o trimitem ca bias
    if (locality) {
      // Încercăm să obținem location + radius din textul localității
      // Ne bazăm pe faptul că Google face geocoding pe numele localității
      params.components = `country:ro|locality:${encodeURIComponent(locality)}`;
    }

    const googleRes = await axios.get(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      { params }
    );

    if (googleRes.data.status !== 'OK' && googleRes.data.status !== 'ZERO_RESULTS') {
      console.error('Google Places API error:', googleRes.data);
      return res.status(502).json({ error: 'Google Places API error', details: googleRes.data.status });
    }

    const predictions = (googleRes.data.predictions || []).map((p) => ({
      place_id: p.place_id,
      description: p.description,
      structured_formatting: p.structured_formatting,
      terms: p.terms,
    }));

    return res.json({ predictions });
  } catch (err) {
    console.error('Eroare la Google Places autocomplete:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Error fetching from Google Places' });
  }
});

/**
 * GET /places/details?place_id=...
 * Proxy către Google Places Details API.
 * Returnează adresa structurată (stradă, număr, localitate, județ, cod poștal).
 */
router.get('/details', async (req, res) => {
  const { place_id } = req.query;
  if (!place_id) return res.status(400).json({ error: 'Missing place_id query' });

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Google Maps API key not configured' });

  try {
    const googleRes = await axios.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      {
        params: {
          place_id,
          fields: 'address_components,formatted_address,geometry',
          language: 'ro',
          key: apiKey,
        },
      }
    );

    if (googleRes.data.status !== 'OK') {
      console.error('Google Places Details API error:', googleRes.data);
      return res.status(502).json({ error: 'Google Places Details API error', details: googleRes.data.status });
    }

    const result = googleRes.data.result;
    const components = result.address_components || [];

    // Extrage componentele adresei
    const extractComponent = (types) => {
      const comp = components.find((c) => types.some((t) => c.types.includes(t)));
      return comp ? comp.long_name : '';
    };

    const address = {
      place_id,
      formatted_address: result.formatted_address || '',
      strada: extractComponent(['route']),
      numar: extractComponent(['street_number']),
      localitate: extractComponent(['locality', 'administrative_area_level_3', 'sublocality']),
      judet: extractComponent(['administrative_area_level_1']),
      codPostal: extractComponent(['postal_code']),
      tara: extractComponent(['country']),
      lat: result.geometry?.location?.lat || null,
      lng: result.geometry?.location?.lng || null,
    };

    return res.json({ address });
  } catch (err) {
    console.error('Eroare la Google Places details:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Error fetching place details from Google' });
  }
});

module.exports = router;
