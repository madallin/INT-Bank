// routes/login.js
const express = require('express');
const router = express.Router();

router.post('/', async (req, res) => {
  const { phone } = req.body;

  if (!phone || typeof phone !== 'string') {
    return res.status(400).json({ error: 'Număr de telefon invalid' });
  }

  let clientDb;
  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      'SELECT id, contaprobat, termeniacceptati FROM utilizatori WHERE nrtelefon = $1 LIMIT 1',
      [phone]
    );

    if (result.rows.length === 0) {
      return res.json({ exists: false });
    }

    const user = result.rows[0];

    return res.json({
      exists: true,
      userId: user.id,
      approved: user.contaprobat,
      acceptedterms: user.termeniacceptati,
    });
  } catch (err) {
    console.error('Eroare la baza de date (login):', err);
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

module.exports = router;
