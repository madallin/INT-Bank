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

  // Construim adresa completă cu toate componentele
  const addressParts = [
    addr.strada,
    addr.numar ? `Nr. ${addr.numar}` : '',
    addr.bloc ? `Bl. ${addr.bloc}` : '',
    addr.scara ? `Sc. ${addr.scara}` : '',
    addr.apartament ? `Ap. ${addr.apartament}` : '',
  ].filter(Boolean);

  let clientDb;
  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      `INSERT INTO utilizatori
      (nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
       judet, localitate, adresa, cod_postal, place_id, lat, lng,
       bloc, scara, apartament)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
      RETURNING id`,
      [
        nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
        addr.judet, addr.localitate,
        addressParts.join(', '),
        addr.codPostal, addr.placeId, addr.lat, addr.lng,
        addr.bloc || null,
        addr.scara || null,
        addr.apartament || null,
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
