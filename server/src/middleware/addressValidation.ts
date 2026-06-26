import { Request, Response, NextFunction } from 'express';
import { Pool } from 'pg';

export interface ValidatedAddress
{
  placeId: string;
  strada: string;
  numar: string;
  bloc: string;
  scara: string;
  apartament: string;
  localitate: string;
  judet: string;
  codPostal: string;
  formattedAddress: string;
  lat: null;
  lng: null;
}

export interface AddressValidationRequest extends Request
{
  addressValidated?: ValidatedAddress;
  pool?: Pool;
}

export async function validateAddress(
  req: AddressValidationRequest,
  res: Response,
  next: NextFunction,
): Promise<void>
{
  const {
    placeId,
    strada,
    numar,
    bloc,
    scara,
    apartament,
    localitate,
    judet,
    codPostal,
  } = req.body;

  if(!placeId)
  {
    res.status(400).json({ error: 'placeId lipsește. Adresa trebuie selectată din sugestii.' });
    return;
  }
  if(!strada || !localitate || !judet)
  {
    res.status(400).json({ error: 'Strada, localitatea și județul sunt obligatorii.' });
    return;
  }

  try
  {
    const client = await req.pool!.connect();
    try
    {
      const refResult = await client.query(
        `SELECT 1 FROM localitati_referinta
         WHERE LOWER(judet) = LOWER($1)
           AND LOWER(localitate) = LOWER($2)
         LIMIT 1`,
        [judet, localitate],
      );

      if(refResult.rows.length === 0)
      {
        res.status(400).json({
          error: `Adresa „${localitate}, ${judet}” nu există în baza noastră de referință. Verifică județul și localitatea.`,
        });
        return;
      }
    }
    finally
    {
      client.release();
    }
  }
  catch (dbErr: any)
  {
    console.error('Eroare la interogarea localitati_referinta:', dbErr.message);
    // Table might not exist — don't block registration in that case
    if(dbErr.code !== '42P01')
    {
      res.status(500).json({ error: 'Eroare internă la validarea adresei' });
      return;
    }
    console.warn('Tabelul localitati_referinta nu există — se omite verificarea în SQL.');
  }

  const addressParts = [
    strada.trim(),
    numar ? `Nr. ${numar}` : '',
    bloc ? `Bl. ${bloc}` : '',
    scara ? `Sc. ${scara}` : '',
    apartament ? `Ap. ${apartament}` : '',
  ].filter(Boolean);

  req.addressValidated = {
    placeId: placeId,
    strada: strada.trim(),
    numar: (numar || '').trim(),
    bloc: (bloc || '').trim(),
    scara: (scara || '').trim(),
    apartament: (apartament || '').trim(),
    localitate: localitate.trim(),
    judet: judet.trim(),
    codPostal: (codPostal || '').trim(),
    formattedAddress: addressParts.join(', '),
    lat: null,
    lng: null,
  };

  next();
}
