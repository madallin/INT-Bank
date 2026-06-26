"use strict";
// ============================================================
// Crypto Service — AES-GCM decryption utilities
// Used for decrypting PAN, CVV, Expiry stored in the database.
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.decryptAESGCM = decryptAESGCM;
exports.safeExtractLast4 = safeExtractLast4;
const crypto_1 = __importDefault(require("crypto"));
const constants_1 = require("../config/constants");
const AES_KEY_HEX_LIST = (process.env.AES_KEY_HEX || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
function hexToBuffer(hex) {
    if (!/^[0-9a-fA-F]+$/.test(hex))
        throw new Error('Key contains non-hex chars');
    return Buffer.from(hex, 'hex');
}
if (AES_KEY_HEX_LIST.length === 0) {
    throw new Error('AES_KEY_HEX env var required (comma separated keys)');
}
const AES_KEYS = AES_KEY_HEX_LIST.map((k) => {
    if (!k || k.length !== 64)
        throw new Error('Each AES key must be 32 bytes hex (64 hex chars)');
    return hexToBuffer(k);
});
/**
 * Decryptează un payload AES-GCM format "v1|<base64(iv|tag|ciphertext)>"
 * încearcă toate cheile din AES_KEYS (rotate keys).
 * Aruncă eroare dacă decriptarea eșuează.
 */
function decryptAESGCM(payload) {
    if (typeof payload !== 'string')
        throw new Error('Invalid encrypted payload type');
    const parts = payload.split('|');
    if (parts.length !== 2)
        throw new Error('Invalid encrypted payload format');
    const version = parts[0];
    const dataStr = parts[1];
    if (version !== 'v1')
        throw new Error('Unsupported encryption version');
    const data = Buffer.from(dataStr, 'base64');
    if (data.length <= constants_1.AES_GCM_IV_BYTES + constants_1.AES_GCM_TAG_BYTES)
        throw new Error('Encrypted payload too short');
    const iv = data.slice(0, constants_1.AES_GCM_IV_BYTES);
    const tag = data.slice(constants_1.AES_GCM_IV_BYTES, constants_1.AES_GCM_IV_BYTES + constants_1.AES_GCM_TAG_BYTES);
    const ciphertext = data.slice(constants_1.AES_GCM_IV_BYTES + constants_1.AES_GCM_TAG_BYTES);
    for (const key of AES_KEYS) {
        try {
            const decipher = crypto_1.default.createDecipheriv('aes-256-gcm', key, iv);
            decipher.setAuthTag(tag);
            const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
            return decrypted.toString('utf8');
        }
        catch (e) {
            // try next key
            continue;
        }
    }
    throw new Error('Decryption failed with all known keys');
}
/**
 * Utility: safeExtractLast4 — încearcă să decripteze PAN-ul;
 * în caz de eroare returnează null. Nu aruncă erori către client.
 */
function safeExtractLast4(panEncrypted) {
    try {
        const pan = decryptAESGCM(panEncrypted);
        if (typeof pan === 'string' && pan.length >= 4)
            return pan.slice(-4);
        return null;
    }
    catch (e) {
        console.error('safeExtractLast4: decryption failed', e.message);
        return null;
    }
}
//# sourceMappingURL=crypto.js.map