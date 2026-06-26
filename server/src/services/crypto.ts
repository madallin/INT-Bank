import crypto from 'crypto';
import { AES_GCM_IV_BYTES, AES_GCM_TAG_BYTES } from '../config/constants';

const ENCRYPTED_PREFIX = 'enc:';
const ALGORITHM = 'aes-256-gcm';

function getEncryptionKey(): Buffer
{
  const raw = process.env.CARD_ENCRYPTION_KEY;
  if(!raw || raw.length === 0)
  {
    throw new Error('CARD_ENCRYPTION_KEY environment variable is not set');
  }
  return crypto.createHash('sha256').update(raw).digest();
}

export function encryptAESGCM(plaintext: string): string
{
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(AES_GCM_IV_BYTES);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag().toString('hex');

  return ENCRYPTED_PREFIX + iv.toString('hex') + tag + encrypted;
}

export function decryptAESGCM(ciphertext: string): string
{
  if(!ciphertext.startsWith(ENCRYPTED_PREFIX))
  {
    throw new Error('Invalid encrypted data format: missing prefix');
  }

  const payload = ciphertext.slice(ENCRYPTED_PREFIX.length);
  const iv = Buffer.from(payload.slice(0, AES_GCM_IV_BYTES * 2), 'hex');
  const tag = Buffer.from(
    payload.slice(AES_GCM_IV_BYTES * 2, AES_GCM_IV_BYTES * 2 + AES_GCM_TAG_BYTES * 2),
    'hex',
  );
  const encrypted = payload.slice(AES_GCM_IV_BYTES * 2 + AES_GCM_TAG_BYTES * 2);

  const key = getEncryptionKey();
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

export function safeExtractLast4(encryptedCard: string): string | null
{
  try
  {
    const raw = decryptAESGCM(encryptedCard);
    return raw.slice(-4);
  }
  catch
  {
    return null;
  }
}
