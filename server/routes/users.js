// routes/users.js
const express = require('express');
const bcrypt = require('bcrypt');
const { createAccountAndCard } = require('../services/banking');
const { decryptAESGCM, safeExtractLast4 } = require('../services/crypto');
const { getRates, convertCurrency } = require('../services/currency');
const router = express.Router();

// Middleware pentru conectarea la DB, verifyClientToken, etc. dacă e nevoie
// const { verifyClientToken } = require('../middleware/auth');

// ruta PUT pentru acceptarea TOS
router.put('/:userId/accept-tos', async (req, res) => {
  const { userId } = req.params;

  let clientDb;
  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      `UPDATE utilizatori
       SET termeniAcceptati = true
       WHERE id = $1
       RETURNING id`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
    }

    const updatedUser = result.rows[0];
    return res.status(200).json({ success: true, user: updatedUser });
  } catch (err) {
    console.error('Eroare la baza de date (accept-tos):', err);
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

// ruta GET pentru a verifica dacă userul a acceptat TOS
router.get('/:userId/has-tos', async (req, res) => {
  const { userId } = req.params;

  let clientDb;
  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      `SELECT termeniacceptati
       FROM utilizatori
       WHERE id = $1`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
    }

    const { termeniacceptati } = result.rows[0];
    return res.status(200).json({ termeniAcceptati: termeniacceptati });
  } catch (err) {
    console.error('Eroare la baza de date (check-tos):', err);
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.post('/:userId/verify-pin', async (req, res) => {
  const { userId } = req.params;
  const { pin } = req.body; // PIN introdus de user
  let clientDb;

  try {
    clientDb = await req.pool.connect();
    const result = await clientDb.query(
      'SELECT pincont FROM utilizatori WHERE id = $1',
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Utilizatorul nu a fost găsit' });
    }

    const pinHash = result.rows[0].pincont;

    if (!pinHash) {
      return res.status(400).json({ success: false, error: 'PIN-ul nu este setat' });
    }

    const match = await bcrypt.compare(pin, pinHash);
    if (match) {
      return res.status(200).json({ success: true });
    } else {
      return res.status(200).json({ success: false });
    }


  } catch (err) {
    console.error('Eroare la verificarea PIN-ului:', err);
    return res.status(500).json({ success: false, error: 'Eroare la server' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.put('/:userId/set-pin', async (req, res) => {
  const { userId } = req.params;
  const { codPin } = req.body;

  // validare: exact 6 cifre
  if (!codPin || !/^\d{6}$/.test(codPin)) {
    return res.status(400).json({ error: 'PIN invalid (trebuie să fie 6 cifre)' });
  }

  // salt rounds - configurabil; 12 este un compromis rezonabil
  const SALT_ROUNDS = 12;

  let clientDb;
  try {
    const hashedPin = await bcrypt.hash(codPin, SALT_ROUNDS);

    clientDb = await req.pool.connect();
    const result = await clientDb.query(
      `UPDATE utilizatori SET pincont = $1 WHERE id = $2 RETURNING id`, [hashedPin, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
    }

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Eroare la baza de date (set-pin):', err);
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.get('/:userId/has-approved', async (req, res) => {
  const { userId } = req.params;
  let clientDb;

  try {
    clientDb = await req.pool.connect();

    const result = await clientDb.query(
      `SELECT contaprobat
       FROM utilizatori
       WHERE id = $1`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
    }

    const { contaprobat } = result.rows[0];
    return res.status(200).json({ contaprobat: contaprobat });
  } catch (err) {
    console.error('Eroare la baza de date (has-approved):', err);
    return res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.post('/:userId/create-account-and-card', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  const { holderName, currency, countryCode } = req.body || {};

  if (!userId || !holderName) {
    return res.status(400).json({ success: false, error: 'userId și holderName sunt obligatorii' });
  }

  try {
    const result = await createAccountAndCard(userId, holderName, currency || 'RON', countryCode || 'RO');

    return res.status(200).json({
      success: true,
      account: {
        id: result.account.id,
        IBAN: result.account.IBAN,
        moneda: result.account.moneda,
        sold: result.account.sold
      },
      card: {
        id: result.card.id,
        token: result.card.token,
        last4: result.card.last4,
        expiry: result.card.expiryMMYY
      }
    });
  } catch (err) {
    console.error('create-account-and-card error:', err);
    return res.status(500).json({ success: false, error: 'Nu s-a putut crea contul/cardul' });
  }
});

router.get('/:userId/cards', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (!userId || userId <= 0) {
    return res.status(400).json({ success: false, error: 'userId invalid' });
  }

  let client;
  try {
    client = await req.pool.connect();

    const q = `
      SELECT id, token, numarcard, dataexpirare, detinator, accountid
      FROM carduri
      WHERE userid = $1
      ORDER BY id
    `;
    const result = await client.query(q, [userId]);

    if (result.rowCount === 0) {
      return res.status(200).json({ success: true, cards: [] });
    }

    const cards = result.rows.map(row => {
      const last4 = safeExtractLast4(row.numarcard) || '****';
      let expiry = null;
      try {
        expiry = decryptAESGCM(row.dataexpirare); // MM/YY
      } catch (e) {
        console.warn('Expiry decryption failed for card id', row.id, e.message);
      }

      return {
        id: row.id,
        token: row.token,
        detinator: row.detinator,
        last4,
        expiry,
        accountId: row.accountid || null, // ✅ aici adăugăm legătura cu contul
      };
    });

    return res.status(200).json({ success: true, cards });
  } catch (err) {
    console.error('GET /users/:userId/cards error:', err);
    return res.status(500).json({ success: false, error: 'Server error' });
  } finally {
    if (client) client.release();
  }
});

router.get('/:userId/accounts/:accountId', async (req, res) => {
  const { userId, accountId } = req.params;
  const client = await req.pool.connect();
  try {
    const result = await client.query(
      `SELECT id, IBAN, sold, moneda FROM conturiBancare WHERE userid = $1 AND id = $2`,
      [userId, accountId]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Cont inexistent' });

    return res.json({ account: result.rows[0] });
  } finally {
    client.release();
  }
});

router.get('/:userId/cards/:cardId/details', async (req, res) => {
  const { userId, cardId } = req.params;
  let client;
  try {
    client = await req.pool.connect();
    const result = await client.query(
      `SELECT numarcard, cvv, dataexpirare, detinator
       FROM carduri
       WHERE id = $1 AND userid = $2`,
      [cardId, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Card inexistent' });
    }

    const row = result.rows[0];
    let pan, cvv, expiry;
    try {
      pan = decryptAESGCM(row.numarcard);
      cvv = decryptAESGCM(row.cvv);
      expiry = decryptAESGCM(row.dataexpirare);
    } catch (e) {
      return res.status(500).json({ success: false, error: 'Decryption failed' });
    }

    return res.json({
      success: true,
      card: {
        detinator: row.detinator,
        pan,
        cvv,
        expiry,
      },
    });
  } catch (err) {
    console.error('Error fetching card details:', err);
    return res.status(500).json({ success: false, error: 'Server error' });
  } finally {
    if (client) client.release();
  }
});

router.post('/:userId/transfer', async (req, res) => {
  const senderUserId = parseInt(req.params.userId, 10);
  const { iban: rawIban, beneficiaryName, amount, reason, senderAccountId, senderName } = req.body;

  if (!senderUserId || isNaN(senderUserId)) 
    return res.status(400).json({ error: 'userId invalid' });

  const iban = (rawIban || '').replace(/\s+/g, '').toUpperCase();

  if (!isValidIBAN(iban)) return res.status(400).json({ error: 'IBAN invalid' });
  if (!beneficiaryName || beneficiaryName.trim().length === 0)
    return res.status(400).json({ error: 'Nume beneficiar necesar' });

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || !Number.isInteger(numericAmount))
    return res.status(400).json({ error: 'Sumă invalidă (trebuie număr întreg)' });
  if (numericAmount < 5) return res.status(400).json({ error: 'Suma minimă este 5' });
  if (!reason || reason.trim().length <= 3) return res.status(400).json({ error: 'Motiv prea scurt (minim 4 caractere)' });

  let client;
  try {
    client = await req.pool.connect();
    try {
      await client.query('BEGIN');

      // 1️⃣ Cont expeditor
      let qSender = `SELECT c.id, c.userid, c.IBAN, c.sold, c.moneda, u.nume as owner_name
                     FROM conturiBancare c
                     JOIN utilizatori u ON u.id = c.userid
                     WHERE c.userid = $1`;
      const qParams = [senderUserId];
      if (senderAccountId) {
        qSender += ' AND c.id=$2';
        qParams.push(senderAccountId);
      }
      const senderRes = await client.query(qSender, qParams);
      if (senderRes.rowCount === 0) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Cont expeditor inexistent' }); }
      const sender = senderRes.rows[0];

      if (senderName?.trim().toLowerCase() !== sender.owner_name.trim().toLowerCase()) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Numele expeditorului nu corespunde contului' });
      }

      // 2️⃣ Cont destinatar
      const receiverRes = await client.query(
        `SELECT c.id, c.userid, c.IBAN, c.sold, c.moneda, u.nume as owner_name
         FROM conturiBancare c
         JOIN utilizatori u ON u.id = c.userid
         WHERE REPLACE(c.IBAN, ' ', '') = $1`,
        [iban]
      );
      if (receiverRes.rowCount === 0) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Cont destinatar inexistent' }); }
      const receiver = receiverRes.rows[0];

      if (receiver.owner_name.trim().toLowerCase() !== beneficiaryName.trim().toLowerCase()) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Numele beneficiarului nu corespunde IBAN-ului' });
      }

      // 3️⃣ Lock conturi pentru tranzacție atomică
      const lockSender = await client.query(`SELECT sold FROM conturiBancare WHERE id=$1 FOR UPDATE`, [sender.id]);
      const lockReceiver = await client.query(`SELECT sold FROM conturiBancare WHERE id=$1 FOR UPDATE`, [receiver.id]);
      const senderSold = Number(lockSender.rows[0].sold) || 0;
      if (senderSold < numericAmount) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'Fonduri insuficiente' }); }

      // 4️⃣ Conversie valutara
      const convertedAmount = await convertCurrency(numericAmount, sender.moneda, receiver.moneda);

      // 5️⃣ Actualizare solduri
      await client.query(`UPDATE conturiBancare SET sold=$1 WHERE id=$2`, [(senderSold - numericAmount).toFixed(2), sender.id]);
      await client.query(`UPDATE conturiBancare SET sold=$1 WHERE id=$2`, [(Number(lockReceiver.rows[0].sold) + convertedAmount).toFixed(2), receiver.id]);

      // 6️⃣ Inserare transfer
      const insertRes = await client.query(
        `INSERT INTO transferuri (expeditor, receptor, suma, moneda, motiv)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING id, dataTransfer`,
        [sender.id, receiver.id, numericAmount, sender.moneda, reason]
      );

      await client.query('COMMIT');

      const inserted = insertRes.rows[0];
      return res.status(200).json({
        success: true,
        transfer: {
          id: inserted.id,
          dataTransfer: inserted.datatransfer,
          fromAccountId: sender.id,
          toAccountId: receiver.id,
          amount: numericAmount,
          currency: sender.moneda,
          amountReceived: convertedAmount,
          currencyReceived: receiver.moneda,
          reason
        }
      });

    } catch (err) {
      await client.query('ROLLBACK');
      console.error('Eroare tranzactie transfer:', err);
      return res.status(500).json({ error: 'Eroare la procesare transfer' });
    }
  } catch (err) {
    console.error('Eroare conexiune DB:', err);
    return res.status(500).json({ error: 'Eroare server' });
  } finally {
    if (client) client.release();
  }
});

router.get('/:userId/accounts/:accountId/transactions', async (req, res) => {
  const { userId, accountId } = req.params;
  const client = await req.pool.connect();

  try {
    const result = await client.query(
      `
      SELECT
        t.id,
        t.expeditor,
        t.receptor,
        t.suma,
        t.moneda,
        t.dataTransfer,
        t.motiv,
        CASE
          WHEN t.expeditor = $2 THEN 'sent'
          ELSE 'received'
        END AS type,
        CASE
          WHEN t.expeditor = $2 THEN (SELECT iban FROM conturiBancare WHERE id = t.receptor)
          ELSE (SELECT iban FROM conturiBancare WHERE id = t.expeditor)
        END AS beneficiary
      FROM transferuri t
      WHERE t.expeditor = $2 OR t.receptor = $2
      ORDER BY t.dataTransfer DESC
      LIMIT 50
      `,
      [userId, accountId]
    );

    if (result.rowCount === 0)
      return res.status(404).json({ error: 'Nu există tranzacții pentru acest cont' });

    return res.json({ transactions: result.rows });
  } finally {
    client.release();
  }
});

module.exports = router;