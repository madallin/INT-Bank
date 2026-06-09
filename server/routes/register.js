// routes/register.js
const express = require('express');
const router = express.Router();
const { validateAddress } = require('../middleware/addressValidation');

router.post('/', validateAddress, async (req, res) => {
  const {
    nume,
    prenume,
    email,
    nrtelefon,
    sex,
    datanasterii,
    cnp,
  } = req.body;

  // Adresa validată de middleware
  const addr = req.addressValidated;

  // Validare minimală
  if (!nume || !prenume || !email || !nrtelefon || !sex ||
      !datanasterii || !cnp) {
    return res.status(400).json({ error: 'Toate câmpurile sunt obligatorii' });
  }

  let clientDb;
  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      `INSERT INTO utilizatori
      (nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
       judet, localitate, adresa, cod_postal, place_id, lat, lng)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      RETURNING id`,
      [
        nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
        addr.judet, addr.localitate,
        [addr.strada, addr.numar, addr.scaraEtajAp].filter(Boolean).join(', '),
        addr.codPostal, addr.placeId, addr.lat, addr.lng,
      ]
    );

    const user = result.rows[0];
    return res.status(201).json({ success: true, user });
  } catch (err) {
    console.error('Eroare la baza de date (register):', err);
    if (err.code === '23505') {
      return res.status(400).json({ error: 'Email sau CNP deja existent' });
    }
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

module.exports = router;
