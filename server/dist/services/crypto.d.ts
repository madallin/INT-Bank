/**
 * Decryptează un payload AES-GCM format "v1|<base64(iv|tag|ciphertext)>"
 * încearcă toate cheile din AES_KEYS (rotate keys).
 * Aruncă eroare dacă decriptarea eșuează.
 */
declare function decryptAESGCM(payload: string): string;
/**
 * Utility: safeExtractLast4 — încearcă să decripteze PAN-ul;
 * în caz de eroare returnează null. Nu aruncă erori către client.
 */
declare function safeExtractLast4(panEncrypted: string): string | null;
export { decryptAESGCM, safeExtractLast4 };
//# sourceMappingURL=crypto.d.ts.map