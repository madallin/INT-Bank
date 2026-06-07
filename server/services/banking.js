'use strict';

/**
 * Banking account + card creation service (production-ready logic)
 * - AES-GCM encryption for PAN/CVV/expiry
 * - HMAC-SHA256 for PAN hashing
 * - Luhn validation for card numbers
 * - Simple IBAN generator (internal scheme)
 * - DB transaction with retry on unique constraint violations
 * - Never returns PAN/CVV in plaintext
 */

const crypto = require('crypto');
const { pool } = require('../config/database');
const {
  BANK_CODE,
  IBAN_ACCOUNT_LENGTH,
  CARD_BIN,
  CARD_LENGTH,
  DEFAULT_CARD_LIFETIME_YEARS,
  MAX_RETRIES,
  AES_GCM_IV_BYTES,
} = require('../config/constants');

const AES_GCM_TAG_BYTES = 16;

// ---------- ENV / KEYS ----------
const AES_KEY_HEX_LIST = (process.env.AES_KEY_HEX || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
const HMAC_KEY_HEX = process.env.HMAC_KEY_HEX || '';

function hexToBuffer(hex) {
  if (!/^[0-9a-fA-F]+$/.test(hex))
    throw new Error('Key contains non-hex chars');
  return Buffer.from(hex, 'hex');
}

if (AES_KEY_HEX_LIST.length === 0)
  throw new Error('AES_KEY_HEX env var required');
const AES_KEYS = AES_KEY_HEX_LIST.map((k) => {
  if (!k || k.length !== 64)
    throw new Error('Each AES key must be 32 bytes hex (64 hex chars)');
  return hexToBuffer(k);
});
const AES_PRIMARY_KEY = AES_KEYS[0];

if (!HMAC_KEY_HEX || HMAC_KEY_HEX.length < 64)
  throw new Error('HMAC_KEY_HEX env var must be set (>=64 hex chars)');
const HMAC_KEY = hexToBuffer(HMAC_KEY_HEX);

// ---------- Helper randomness ----------
function randomDigits(len) {
  let out = '';
  while (out.length < len) {
    const next = crypto.randomInt(0, 1e6).toString().padStart(6, '0');
    out += next;
  }
  return out.slice(0, len);
}

// ---------- Luhn / card ----------
function luhnCheckDigit(numberWithoutCheck) {
  const digits = numberWithoutCheck.split('').map((d) => parseInt(d, 10));
  let sum = 0;
  const len = digits.length;
  for (let i = 0; i < len; i++) {
    let d = digits[len - 1 - i];
    if (i % 2 === 0) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return (10 - (sum % 10)) % 10;
}

function validateLuhn(fullNumber) {
  if (!/^[0-9]+$/.test(fullNumber)) return false;
  let sum = 0;
  let alt = false;
  for (let i = fullNumber.length - 1; i >= 0; i--) {
    let d = parseInt(fullNumber[i], 10);
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return sum % 10 === 0;
}

function generateCardPan() {
  while (true) {
    const middle = randomDigits(CARD_LENGTH - CARD_BIN.length - 1);
    const withoutCheck = CARD_BIN + middle;
    const check = luhnCheckDigit(withoutCheck);
    const pan = withoutCheck + check;
    if (validateLuhn(pan)) return pan;
  }
}

function generateCvv() {
  return randomDigits(3);
}

function generateExpiry(
  issueDate = new Date(),
  years = DEFAULT_CARD_LIFETIME_YEARS
) {
  const issueMonth = issueDate.getMonth() + 1;
  const issueYear = issueDate.getFullYear();
  const expYearFull = issueYear + years;
  const lastDay = new Date(expYearFull, issueMonth, 0).getDate();
  const expiryDateISO = new Date(expYearFull, issueMonth - 1, lastDay)
    .toISOString()
    .slice(0, 10);
  const yy = expYearFull.toString().slice(-2);
  const mm = issueMonth.toString().padStart(2, '0');
  return { expiryMMYY: `${mm}/${yy}`, expiryDateISO };
}

function generateToken(pan) {
  return crypto
    .createHash('sha256')
    .update(
      pan + Date.now().toString() + crypto.randomBytes(12).toString('hex')
    )
    .digest('hex')
    .slice(0, 32);
}

// ---------- IBAN helpers ----------
function lettersToNumber(str) {
  return str
    .toUpperCase()
    .split('')
    .map((c) => {
      const code = c.charCodeAt(0);
      if (code >= 65 && code <= 90) return (code - 55).toString();
      return c;
    })
    .join('');
}

function mod97(numericStr) {
  let remainder = 0, i = 0;
  while (i < numericStr.length) {
    const block = numericStr.substr(i, 9);
    remainder = parseInt(remainder.toString() + block, 10) % 97;
    i += 9;
  }
  return remainder;
}

function generateIban(countryCode = 'RO') {
  countryCode = countryCode.toUpperCase();
  if (!/^[A-Z]{2}$/.test(countryCode)) throw new Error('Invalid country code');
  const accountNumber = randomDigits(IBAN_ACCOUNT_LENGTH);
  const rearranged = BANK_CODE + accountNumber + countryCode + '00';
  const numeric = lettersToNumber(rearranged);
  const check = 98 - mod97(numeric);
  return `${countryCode}${check
    .toString()
    .padStart(2, '0')}${BANK_CODE}${accountNumber}`;
}

// ---------- AES-GCM encryption / decryption ----------
function encryptAESGCM(plain) {
  const iv = crypto.randomBytes(AES_GCM_IV_BYTES);
  const cipher = crypto.createCipheriv('aes-256-gcm', AES_PRIMARY_KEY, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plain, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return `v1|${Buffer.concat([iv, tag, ciphertext]).toString('base64')}`;
}

function decryptAESGCM(any) {
  if (typeof any !== 'string') throw new Error('invalid encrypted payload');
  const [version, dataStr] = any.split('|');
  if (version !== 'v1') throw new Error('unsupported enc version');
  const data = Buffer.from(dataStr, 'base64');
  const iv = data.slice(0, AES_GCM_IV_BYTES);
  const tag = data.slice(AES_GCM_IV_BYTES, AES_GCM_IV_BYTES + AES_GCM_TAG_BYTES);
  const ciphertext = data.slice(AES_GCM_IV_BYTES + AES_GCM_TAG_BYTES);
  for (const key of AES_KEYS) {
    try {
      const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
      decipher.setAuthTag(tag);
      return Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]).toString('utf8');
    } catch (e) {
      continue;
    }
  }
  throw new Error('decryption failed with all known keys');
}

function panHash(pan) {
  return crypto.createHmac('sha256', HMAC_KEY).update(pan).digest('hex');
}

// ---------- DB insert with retry ----------
async function createAccountAndCard(
  userId,
  currency = 'RON',
  countryCode = 'RO'
) {
  if (!Number.isInteger(userId) || userId <= 0)
    throw new Error('invalid userId');

  const client = await pool.connect();
  try {
    // Preluăm prenume + nume din utilizatori
    const userRes = await client.query(
      'SELECT prenume, nume FROM utilizatori WHERE id = $1',
      [userId]
    );
    if (userRes.rowCount === 0) throw new Error('User not found');

    const holderName = `${userRes.rows[0].prenume} ${userRes.rows[0].nume}`;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      const iban = generateIban(countryCode);
      const pan = generateCardPan();
      const cvv = generateCvv();
      const { expiryMMYY, expiryDateISO } = generateExpiry();
      const token = generateToken(pan);
      const encrypted_pan = encryptAESGCM(pan);
      const encrypted_cvv = encryptAESGCM(cvv);
      const encrypted_expiry = encryptAESGCM(expiryMMYY);

      try {
        await client.query('BEGIN');

        const accountRes = await client.query(
          `INSERT INTO conturiBancare(userid, IBAN, moneda, sold)
           VALUES($1,$2,$3,0.0)
           RETURNING id, IBAN, moneda, sold`,
          [userId, iban, currency.toUpperCase()]
        );

        const cardRes = await client.query(
          `INSERT INTO carduri(userid, numarCard, CVV, dataExpirare, detinator, token)
           VALUES($1,$2,$3,$4,$5,$6)
           RETURNING id, token`,
          [
            userId,
            encrypted_pan,
            encrypted_cvv,
            encrypted_expiry,
            holderName,
            token,
          ]
        );

        await client.query('COMMIT');

        return {
          account: accountRes.rows[0],
          card: {
            id: cardRes.rows[0].id,
            token: cardRes.rows[0].token,
            last4: pan.slice(-4),
            expiryMMYY,
          },
        };
      } catch (err) {
        await client.query('ROLLBACK');
        if (err.code === '23505') {
          console.warn(
            'Unique constraint violation, retrying',
            attempt + 1,
            err.constraint || err.detail || err.message
          );
          continue;
        } else throw err;
      }
    }
    throw new Error('Could not generate unique IBAN/card after max retries');
  } finally {
    client.release();
  }
}

// ---------- Exports ----------
module.exports = { createAccountAndCard };
