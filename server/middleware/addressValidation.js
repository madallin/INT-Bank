// middleware/addressValidation.js
// Validează adresa primită de la frontend:
//   a) Verifică place_id prin Geoapify Geocoding Search API
//   b) Compară localitatea + județul cu tabelul SQL de referință
//   c) Returnează obiectul adresei standardizat sau eroare

const axios = require('axios');

const GEOAPIFY_BASE = 'https://api.geoapify.com/v1/geocode';

/**
 * Middleware de validare a adresei.
 * Așteaptă în req.body: { placeId, strada, numar, localitate, judet, codPostal }
 * La succes, adaugă req.addressValidated = { ... } (obiectul standardizat).
 * La eșec, returnează 400 cu eroarea.
 */
async function validateAddress(req, res, next) {
  const {
    placeId,
    strada,
    numar,
    localitate,
    judet,
    codPostal,
  } = req.body;

  // --- Validare câmpuri obligatorii ---
  if (!placeId) {
    return res.status(400).json({ error: 'placeId lipsește. Adresa trebuie selectată din sugestii.' });
  }
  if (!strada || !localitate || !judet) {
    return res.status(400).json({ error: 'Strada, localitatea și județul sunt obligatorii.' });
  }

  const apiKey = process.env.GEOAPIFY_KEY;
  if (!apiKey) {
    console.error('GEOAPIFY_KEY neconfigurată');
    return res.status(500).json({ error: 'Configurare internă invalidă' });
  }

  try {
    // --- (a) Verifică place_id prin Geoapify Geocoding Search API ---
    const geoapifyRes = await axios.get(
      `${GEOAPIFY_BASE}/search`,
      {
        params: {
          id: placeId,
          format: 'json',
          lang: 'ro',
          apiKey,
        },
      }
    );

    const results = geoapifyRes.data?.results || [];
    if (results.length === 0) {
      return res.status(400).json({
        error: 'Adresa nu a putut fi validată. Te rugăm să selectezi o adresă din sugestii.',
        details: 'Geoapify: no results for place_id',
      });
    }

    const result = results[0];

    // Extrage componentele din răspunsul Geoapify
    const geoJudet = result.state || '';
    const geoLocalitate = result.city || result.county || '';
    const geoStrada = result.street || '';
    const geoNumar = result.housenumber || '';
    const geoCodPostal = result.postcode || '';

    // --- Verificare corespondență județ ---
    if (geoJudet && geoJudet.toLowerCase() !== judet.toLowerCase()) {
      return res.status(400).json({
        error: `Județul selectat (${judet}) nu corespunde cu adresa din Geoapify (${geoJudet}).`,
      });
    }

    // --- Verificare corespondență localitate ---
    if (geoLocalitate && geoLocalitate.toLowerCase() !== localitate.toLowerCase()) {
      return res.status(400).json({
        error: `Localitatea selectată (${localitate}) nu corespunde cu adresa din Geoapify (${geoLocalitate}).`,
      });
    }

    // --- (b) Verifică localitatea + județul în tabelul SQL de referință ---
    try {
      const client = await req.pool.connect();
      try {
        const refResult = await client.query(
          `SELECT 1 FROM localitati_referinta
           WHERE LOWER(judet) = LOWER($1)
             AND LOWER(localitate) = LOWER($2)
           LIMIT 1`,
          [judet, localitate]
        );

        if (refResult.rows.length === 0) {
          return res.status(400).json({
            error: `Adresa „${localitate}, ${judet}” nu există în baza noastră de referință. Verifică județul și localitatea.`,
          });
        }
      } finally {
        client.release();
      }
    } catch (dbErr) {
      console.error('Eroare la interogarea localitati_referinta:', dbErr.message);
      // Dacă tabelul nu există, nu blocăm — e configurabil
      if (dbErr.code !== '42P01') { // 42P01 = undefined_table
        return res.status(500).json({ error: 'Eroare internă la validarea adresei' });
      }
      console.warn('Tabelul localitati_referinta nu există — se omite verificarea în SQL.');
    }

    // --- (c) Totul e valid → obiect standardizat ---
    req.addressValidated = {
      placeId: placeId,
      strada: strada.trim(),
      numar: (numar || '').trim(),
      localitate: localitate.trim(),
      judet: judet.trim(),
      codPostal: (codPostal || geoCodPostal || '').trim(),
      formattedAddress: result.formatted || '',
      lat: result.lat || null,
      lng: result.lon || null,
    };

    next();
  } catch (err) {
    console.error('Eroare la validarea adresei:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Eroare la comunicarea cu Geoapify API' });
  }
}

module.exports = { validateAddress };
