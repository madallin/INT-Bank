import { Request, Response, NextFunction } from 'express';
import { DataSource } from 'typeorm';
import { AppDataSource } from '../config/database';
import { logger } from '../config/logger';

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
  dataSource?: DataSource;
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
    if(AppDataSource.isInitialized)
    {
      try
      {
        const refResult = await AppDataSource.query(
          `SELECT 1 FROM localitati_referinta
           WHERE LOWER(judet) = LOWER($1)
             AND LOWER(localitate) = LOWER($2)
           LIMIT 1`,
          [judet, localitate],
        );

        if(refResult.length === 0)
        {
          res.status(400).json({
            error: `Adresa „${localitate}, ${judet}” nu există în baza noastră de referință. Verifică județul și localitatea.`,
          });
          return;
        }
      }
      catch (dbErr: any)
      {
        logger.error(dbErr, 'Eroare la interogarea localitati_referinta');
        if(dbErr.code !== '42P01')
        {
          res.status(500).json({ error: 'Eroare internă la validarea adresei' });
          return;
        }
        logger.warn('Tabelul localitati_referinta nu există — se omite verificarea în SQL.');
      }
    }
  }
  catch (err)
  {
    logger.warn('DataSource not initialized, skipping reference check');
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
