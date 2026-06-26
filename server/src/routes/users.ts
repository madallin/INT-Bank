// ============================================================
// Route: Users — User profile, banking, cards, transfers
// ============================================================

import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { Pool } from 'pg';
import { createAccountAndCard } from '../services/banking';
import { decryptAESGCM, safeExtractLast4 } from '../services/crypto';
import { convertCurrency } from '../services/currency';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
interface UsersRequest extends Request<any, any, any, any> {
  pool?: Pool;
}

const router = Router();

// Helper: validare IBAN simplă
function isValidIBAN(iban: string): boolean {
  return /^[A-Z]{2}[0-9A-Z]{14,30}$/.test(iban);
}

// ruta PUT pentru acceptarea TOS
router.put('/:userId/accept-tos', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;

  let clientDb;
  try {
    clientDb = await req.pool!.connect();

    const result = await clientDb.query(
      `UPDATE utilizatori
       SET termeniAcceptati = true
       WHERE id = $1
       RETURNING id`,
      [userId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    const updatedUser = result.rows[0];
    res.status(200).json({ success: true, user: updatedUser });
  } catch (err) {
    console.error('Eroare la baza de date (accept-tos):', err);
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

// ruta GET pentru a verifica dacă userul a acceptat TOS
router.get('/:userId/has-tos', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;

  let clientDb;
  try {
    clientDb = await req.pool!.connect();

    const result = await clientDb.query(
      `SELECT termeniacceptati
       FROM utilizatori
       WHERE id = $1`,
      [userId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    const { termeniacceptati } = result.rows[0];
    res.status(200).json({ termeniAcceptati: termeniacceptati });
  } catch (err) {
    console.error('Eroare la baza de date (check-tos):', err);
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.post('/:userId/verify-pin', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;
  const { pin } = req.body;
  let clientDb;

  try {
    clientDb = await req.pool!.connect();
    const result = await clientDb.query('SELECT pincont FROM utilizatori WHERE id = $1', [userId]);

    if (result.rowCount === 0) {
      res.status(404).json({ success: false, error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    const pinHash = result.rows[0].pincont;

    if (!pinHash) {
      res.status(400).json({ success: false, error: 'PIN-ul nu este setat' });
      return;
    }

    const match = await bcrypt.compare(pin, pinHash);
    res.status(200).json({ success: match });
  } catch (err) {
    console.error('Eroare la verificarea PIN-ului:', err);
    res.status(500).json({ success: false, error: 'Eroare la server' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.get('/:userId/has-pin', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;

  let clientDb;
  try {
    clientDb = await req.pool!.connect();
    const result = await clientDb.query('SELECT pincont FROM utilizatori WHERE id = $1', [userId]);

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    const hasPin = result.rows[0].pincont !== null && result.rows[0].pincont !== '';
    res.status(200).json({ hasPin });
  } catch (err) {
    console.error('Eroare la baza de date (has-pin):', err);
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.put('/:userId/set-pin', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;
  const { codPin } = req.body;

  if (!codPin || !/^\d{6}$/.test(codPin)) {
    res.status(400).json({ error: 'PIN invalid (trebuie să fie 6 cifre)' });
    return;
  }

  const SALT_ROUNDS = 12;

  let clientDb;
  try {
    const hashedPin = await bcrypt.hash(codPin, SALT_ROUNDS);

    clientDb = await req.pool!.connect();
    const result = await clientDb.query(
      `UPDATE utilizatori SET pincont = $1 WHERE id = $2 RETURNING id`,
      [hashedPin, userId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    res.status(200).json({ success: true });
  } catch (err) {
    console.error('Eroare la baza de date (set-pin):', err);
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.get('/:userId/has-approved', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;

  let clientDb;
  try {
    clientDb = await req.pool!.connect();

    const result = await clientDb.query(
      `SELECT contaprobat
       FROM utilizatori
       WHERE id = $1`,
      [userId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Utilizatorul nu a fost găsit' });
      return;
    }

    const { contaprobat } = result.rows[0];
    res.status(200).json({ contaprobat });
  } catch (err) {
    console.error('Eroare la baza de date (has-approved):', err);
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

router.post('/:userId/create-account-and-card', async (req: UsersRequest, res: Response) => {
  const userId = parseInt(req.params.userId, 10);
  const { currency, countryCode } = req.body || {};

  if (!userId) {
    res.status(400).json({ success: false, error: 'userId este obligatoriu' });
    return;
  }

  try {
    const result = await createAccountAndCard(userId, currency || 'RON', countryCode || 'RO');

    res.status(200).json({
      success: true,
      account: {
        id: result.account.id,
        IBAN: result.account.IBAN,
        moneda: result.account.moneda,
        sold: result.account.sold,
      },
      card: {
        id: result.card.id,
        token: result.card.token,
        last4: result.card.last4,
        expiry: result.card.expiryMMYY,
        accountId: result.card.accountId,
      },
    });
  } catch (err) {
    console.error('create-account-and-card error:', err);
    res.status(500).json({ success: false, error: 'Nu s-a putut crea contul/cardul' });
  }
});

router.get('/:userId/cards', async (req: UsersRequest, res: Response) => {
  const userId = parseInt(req.params.userId, 10);
  if (!userId || userId <= 0) {
    res.status(400).json({ success: false, error: 'userId invalid' });
    return;
  }

  let client;
  try {
    client = await req.pool!.connect();

    const q = `
      SELECT id, token, numarcard, dataexpirare, detinator, accountid
      FROM carduri
      WHERE userid = $1
      ORDER BY id
    `;
    const result = await client.query(q, [userId]);

    if (result.rowCount === 0) {
      res.status(200).json({ success: true, cards: [] });
      return;
    }

    let fallbackAccountId: number | null = null;
    const hasNullAccountId = result.rows.some((row: any) => row.accountid == null);
    if (hasNullAccountId) {
      const accountRes = await client.query(
        'SELECT id FROM conturiBancare WHERE userid = $1 ORDER BY id LIMIT 1',
        [userId],
      );
      if (accountRes.rowCount > 0) {
        fallbackAccountId = accountRes.rows[0].id;
      }
    }

    const cards = result.rows.map((row: any) => {
      const last4 = safeExtractLast4(row.numarcard) || '****';
      let expiry: string | null = null;
      try {
        expiry = decryptAESGCM(row.dataexpirare);
      } catch (e: any) {
        console.warn('Expiry decryption failed for card id', row.id, e.message);
      }

      return {
        id: row.id,
        token: row.token,
        detinator: row.detinator,
        last4,
        expiry,
        accountId: row.accountid || fallbackAccountId,
      };
    });

    res.status(200).json({ success: true, cards });
  } catch (err) {
    console.error('GET /users/:userId/cards error:', err);
    res.status(500).json({ success: false, error: 'Server error' });
  } finally {
    if (client) client.release();
  }
});

router.get('/:userId/accounts/:accountId', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;
  const accountId = req.params.accountId;
  const client = await req.pool!.connect();
  try {
    const result = await client.query(
      `SELECT id, IBAN, sold, moneda FROM conturiBancare WHERE userid = $1 AND id = $2`,
      [userId, accountId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Cont inexistent' });
      return;
    }

    res.json({ account: result.rows[0] });
  } finally {
    client.release();
  }
});

router.get('/:userId/cards/:cardId/details', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;
  const cardId = req.params.cardId;
  let client;
  try {
    client = await req.pool!.connect();
    const result = await client.query(
      `SELECT numarcard, cvv, dataexpirare, detinator
       FROM carduri
       WHERE id = $1 AND userid = $2`,
      [cardId, userId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ success: false, error: 'Card inexistent' });
      return;
    }

    const row = result.rows[0];
    let pan: string, cvv: string, expiry: string;
    try {
      pan = decryptAESGCM(row.numarcard);
      cvv = decryptAESGCM(row.cvv);
      expiry = decryptAESGCM(row.dataexpirare);
    } catch (e) {
      res.status(500).json({ success: false, error: 'Decryption failed' });
      return;
    }

    res.json({
      success: true,
      card: { detinator: row.detinator, pan, cvv, expiry },
    });
  } catch (err) {
    console.error('Error fetching card details:', err);
    res.status(500).json({ success: false, error: 'Server error' });
  } finally {
    if (client) client.release();
  }
});

router.post('/:userId/transfer', async (req: UsersRequest, res: Response) => {
  const senderUserId = parseInt(req.params.userId, 10);
  const { iban: rawIban, beneficiaryName, amount, reason, senderAccountId, senderName } = req.body;

  if (!senderUserId || isNaN(senderUserId)) {
    res.status(400).json({ error: 'userId invalid' });
    return;
  }

  const iban = (rawIban || '').replace(/\s+/g, '').toUpperCase();

  if (!isValidIBAN(iban)) {
    res.status(400).json({ error: 'IBAN invalid' });
    return;
  }
  if (!beneficiaryName || beneficiaryName.trim().length === 0) {
    res.status(400).json({ error: 'Nume beneficiar necesar' });
    return;
  }

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || !Number.isInteger(numericAmount)) {
    res.status(400).json({ error: 'Sumă invalidă (trebuie număr întreg)' });
    return;
  }
  if (numericAmount < 5) {
    res.status(400).json({ error: 'Suma minimă este 5' });
    return;
  }
  if (!reason || reason.trim().length <= 3) {
    res.status(400).json({ error: 'Motiv prea scurt (minim 4 caractere)' });
    return;
  }

  let client;
  try {
    client = await req.pool!.connect();
    try {
      await client.query('BEGIN');

      // 1️⃣ Cont expeditor
      let qSender = `SELECT c.id, c.userid, c.IBAN, c.sold, c.moneda, u.nume as owner_name
                     FROM conturiBancare c
                     JOIN utilizatori u ON u.id = c.userid
                     WHERE c.userid = $1`;
      const qParams: any[] = [senderUserId];
      if (senderAccountId) {
        qSender += ' AND c.id=$2';
        qParams.push(senderAccountId);
      }
      const senderRes = await client.query(qSender, qParams);
      if (senderRes.rowCount === 0) {
        await client.query('ROLLBACK');
        res.status(404).json({ error: 'Cont expeditor inexistent' });
        return;
      }
      const sender = senderRes.rows[0];

      if (senderName?.trim().toLowerCase() !== sender.owner_name.trim().toLowerCase()) {
        await client.query('ROLLBACK');
        res.status(400).json({ error: 'Numele expeditorului nu corespunde contului' });
        return;
      }

      // 2️⃣ Cont destinatar
      const receiverRes = await client.query(
        `SELECT c.id, c.userid, c.IBAN, c.sold, c.moneda, u.nume as owner_name
         FROM conturiBancare c
         JOIN utilizatori u ON u.id = c.userid
         WHERE REPLACE(c.IBAN, ' ', '') = $1`,
        [iban],
      );
      if (receiverRes.rowCount === 0) {
        await client.query('ROLLBACK');
        res.status(404).json({ error: 'Cont destinatar inexistent' });
        return;
      }
      const receiver = receiverRes.rows[0];

      if (receiver.owner_name.trim().toLowerCase() !== beneficiaryName.trim().toLowerCase()) {
        await client.query('ROLLBACK');
        res.status(400).json({ error: 'Numele beneficiarului nu corespunde IBAN-ului' });
        return;
      }

      // 3️⃣ Lock conturi pentru tranzacție atomică
      await client.query(`SELECT sold FROM conturiBancare WHERE id=$1 FOR UPDATE`, [sender.id]);
      const lockReceiver = await client.query(`SELECT sold FROM conturiBancare WHERE id=$1 FOR UPDATE`, [receiver.id]);
      const { rows: [lockSenderRow] } = await client.query(`SELECT sold FROM conturiBancare WHERE id=$1 FOR UPDATE`, [sender.id]);
      const senderSold = Number(lockSenderRow.sold) || 0;
      if (senderSold < numericAmount) {
        await client.query('ROLLBACK');
        res.status(400).json({ error: 'Fonduri insuficiente' });
        return;
      }

      // 4️⃣ Conversie valutara
      const convertedAmount = await convertCurrency(numericAmount, sender.moneda, receiver.moneda);

      // 5️⃣ Actualizare solduri
      await client.query(`UPDATE conturiBancare SET sold=$1 WHERE id=$2`, [
        (senderSold - numericAmount).toFixed(2),
        sender.id,
      ]);
      await client.query(`UPDATE conturiBancare SET sold=$1 WHERE id=$2`, [
        (Number(lockReceiver.rows[0].sold) + convertedAmount).toFixed(2),
        receiver.id,
      ]);

      // 6️⃣ Inserare transfer
      const insertRes = await client.query(
        `INSERT INTO transferuri (expeditor, receptor, suma, moneda, motiv)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING id, dataTransfer`,
        [sender.id, receiver.id, numericAmount, sender.moneda, reason],
      );

      await client.query('COMMIT');

      const inserted = insertRes.rows[0];
      res.status(200).json({
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
          reason,
        },
      });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('Eroare tranzactie transfer:', err);
      res.status(500).json({ error: 'Eroare la procesare transfer' });
    }
  } catch (err) {
    console.error('Eroare conexiune DB:', err);
    res.status(500).json({ error: 'Eroare server' });
  } finally {
    if (client) client.release();
  }
});

router.get('/:userId/accounts/:accountId/transactions', async (req: UsersRequest, res: Response) => {
  const userId = req.params.userId;
  const accountId = req.params.accountId;
  const client = await req.pool!.connect();

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
      [userId, accountId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Nu există tranzacții pentru acest cont' });
      return;
    }

    res.json({ transactions: result.rows });
  } finally {
    client.release();
  }
});

export default router;
