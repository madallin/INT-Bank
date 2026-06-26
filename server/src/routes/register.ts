// ============================================================
// Route: Register — User registration with address validation
// ============================================================

import { Router, Response } from 'express';
import { Pool } from 'pg';
import { validateAddress, AddressValidationRequest } from '../middleware/addressValidation';

interface RegisterRequest extends AddressValidationRequest {
  pool?: Pool;
  body: {
    nume?: string;
    prenume?: string;
    email?: string;
    nrtelefon?: string;
    sex?: string;
    datanasterii?: string;
    cnp?: string;
    placeId?: string;
    strada?: string;
    numar?: string;
    bloc?: string;
    scara?: string;
    apartament?: string;
    localitate?: string;
    judet?: string;
    codPostal?: string;
  };
}

const router = Router();

router.post('/', validateAddress, async (req: RegisterRequest, res: Response) => {
  const { nume, prenume, email, nrtelefon, sex, datanasterii, cnp } = req.body;
  const addr = req.addressValidated!;

  // Validare minimală
  if (!nume || !prenume || !email || !nrtelefon || !sex || !datanasterii || !cnp) {
    res.status(400).json({ error: 'Toate câmpurile sunt obligatorii' });
    return;
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
    clientDb = await req.pool!.connect();

    const result = await clientDb.query(
      `INSERT INTO utilizatori
      (nume, prenume, email, nrtelefon, sex, datanasterii, cnp,
       judet, localitate, adresa, cod_postal, place_id, lat, lng,
       bloc, scara, apartament)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
      RETURNING id`,
      [
        nume,
        prenume,
        email,
        nrtelefon,
        sex,
        datanasterii,
        cnp,
        addr.judet,
        addr.localitate,
        addressParts.join(', '),
        addr.codPostal,
        addr.placeId,
        addr.lat,
        addr.lng,
        addr.bloc || null,
        addr.scara || null,
        addr.apartament || null,
      ],
    );

    const user = result.rows[0];
    res.status(201).json({ success: true, user });
  } catch (err: any) {
    console.error('Eroare la baza de date (register):', err);
    if (err.code === '23505') {
      res.status(400).json({ error: 'Email sau CNP deja existent' });
      return;
    }
    res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
  } finally {
    if (clientDb) clientDb.release();
  }
});

export default router;
