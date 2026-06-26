import { pool } from '../config/database';
import { encryptAESGCM } from './crypto';
import { BANK_CODE, IBAN_ACCOUNT_LENGTH, CARD_BIN, CARD_LENGTH, DEFAULT_CARD_LIFETIME_YEARS, MAX_RETRIES } from '../config/constants';

function generateRandomDigits(length: number): string
{
  let result = '';
  for(let i = 0; i < length; i++) result += Math.floor(Math.random() * 10).toString();
  return result;
}

function computeIBANChecksum(bban: string): string
{
  const numeric = [...(bban + 'RO00')].map((c) =>
    /[A-Z]/.test(c) ? (c.charCodeAt(0) - 55).toString() : c,
  ).join('');
  const mod = BigInt(numeric) % 97n;
  const checksum = 98n - mod;
  return checksum.toString().padStart(2, '0');
}

function generateIBAN(currency: string, countryCode: string): string
{
  const country = countryCode.toUpperCase().slice(0, 2);
  const bban =
    BANK_CODE +
    generateRandomDigits(4) +
    (currency === 'RON' ? 'RON' : generateRandomDigits(3)) +
    generateRandomDigits(IBAN_ACCOUNT_LENGTH - BANK_CODE.length - 4 - (currency === 'RON' ? 3 : 3));
  const checksum = computeIBANChecksum(bban);
  return `${country}${checksum}${bban}`;
}

export async function createAccountAndCard(
  userId: number,
  currency: string,
  countryCode: string,
): Promise<{ account: any; card: any }>
{
  const IBAN = generateIBAN(currency, countryCode);

  let client;
  try
  {
    client = await pool.connect();

    const accountResult = await client.query(
      `INSERT INTO conturiBancare (userid, iban, moneda, sold) VALUES ($1,$2,$3,0) RETURNING id, iban, moneda, sold`,
      [userId, IBAN, currency],
    );
    const account = accountResult.rows[0];
    const accountId = account.id;

    const cardNumber = CARD_BIN + generateRandomDigits(CARD_LENGTH - CARD_BIN.length);
    const cvv = generateRandomDigits(3);
    const now = new Date();
    const expiry = new Date(now.getFullYear() + DEFAULT_CARD_LIFETIME_YEARS, now.getMonth(), 1);
    const expiryMMYY = `${(expiry.getMonth() + 1).toString().padStart(2, '0')}/${expiry.getFullYear().toString().slice(-2)}`;

    const encryptedCard = encryptAESGCM(cardNumber);
    const encryptedCVV = encryptAESGCM(cvv);
    const encryptedExpiry = encryptAESGCM(expiryMMYY);

    const cardResult = await client.query(
      `INSERT INTO carduri (userid, numarcard, cvv, dataexpirare, detinator, token, accountid)
       VALUES ($1,$2,$3,$4,'',$5,$6) RETURNING id`,
      [userId, encryptedCard, encryptedCVV, encryptedExpiry, `tok_${generateRandomDigits(16)}`, accountId],
    );

    const card = cardResult.rows[0];
    return {
      account: { id: accountId, IBAN: account.iban, moneda: account.moneda, sold: account.sold },
      card: { id: card.id, token: `tok_${generateRandomDigits(16)}`, last4: cardNumber.slice(-4), expiryMMYY, accountId },
    };
  }
  finally
  {
    if(client) client.release();
  }
}

// Retries on unique constraint violations (concurrent account creation race)
export async function createAccountAndCardWithRetry(
  userId: number,
  currency: string,
  countryCode: string,
  retries: number = MAX_RETRIES,
): Promise<{ account: any; card: any }>
{
  for(let attempt = 1; attempt <= retries; attempt++)
  {
    try
    {
      return await createAccountAndCard(userId, currency, countryCode);
    }
    catch (err: any)
    {
      const isUniqueViolation = err.code === '23505';
      if(isUniqueViolation && attempt < retries)
      {
        console.warn(`IBAN collision on attempt ${attempt}, retrying...`);
        continue;
      }
      throw err;
    }
  }
  throw new Error('Failed to generate unique IBAN after multiple attempts');
}
