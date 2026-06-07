// middleware/addressValidation.js
// Validează adresa primită de la frontend:
//   a) Verifică place_id prin Google Places Details API
//   b) Compară localitatea + județul cu tabelul SQL de referință
//   c) Returnează obiectul adresei standardizat sau eroare

const axios = require('axios');

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

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) {
    console.error('GOOGLE_MAPS_API_KEY neconfigurată');
    return res.status(500).json({ error: 'Configurare internă invalidă' });
  }

  try {
    // --- (a) Verifică place_id prin Google Places Details API ---
    const googleRes = await axios.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      {
        params: {
          place_id: placeId,
          fields: 'address_components,formatted_address,geometry,place_id',
          language: 'ro',
          key: apiKey,
        },
      }
    );

    if (googleRes.data.status !== 'OK' || !googleRes.data.result) {
      return res.status(400).json({
        error: 'Adresa nu a putut fi validată. Te rugăm să selectezi o adresă din sugestii.',
        details: googleRes.data.status,
      });
    }

    const result = googleRes.data.result;
    const components = result.address_components || [];

    // Extrage componentele din răspunsul Google
    const extractComponent = (types) => {
      const comp = components.find((c) => types.some((t) => c.types.includes(t)));
      return comp ? comp.long_name : '';
    };

    const googleJudet = extractComponent(['administrative_area_level_1']);
    const googleLocalitate = extractComponent(['locality', 'administrative_area_level_3', 'sublocality']);
    const googleStrada = extractComponent(['route']);
    const googleNumar = extractComponent(['street_number']);
    const googleCodPostal = extractComponent(['postal_code']);

    // --- Verificare corespondență județ ---
    if (googleJudet && googleJudet.toLowerCase() !== judet.toLowerCase()) {
      return res.status(400).json({
        error: `Județul selectat (${judet}) nu corespunde cu adresa din Google (${googleJudet}).`,
      });
    }

    // --- Verificare corespondență localitate ---
    if (googleLocalitate && googleLocalitate.toLowerCase() !== localitate.toLowerCase()) {
      return res.status(400).json({
        error: `Localitatea selectată (${localitate}) nu corespunde cu adresa din Google (${googleLocalitate}).`,
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
      codPostal: (codPostal || googleCodPostal || '').trim(),
      formattedAddress: result.formatted_address || '',
      lat: result.geometry?.location?.lat || null,
      lng: result.geometry?.location?.lng || null,
    };

    next();
  } catch (err) {
    console.error('Eroare la validarea adresei:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Eroare la comunicarea cu Google Places API' });
  }
}

module.exports = { validateAddress };
