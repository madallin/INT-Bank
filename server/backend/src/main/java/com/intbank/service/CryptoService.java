package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HexFormat;

@Service
public class CryptoService
{

    private static final Logger log = LoggerFactory.getLogger(CryptoService.class);
    private static final String ENCRYPTED_PREFIX = "enc:";
    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int AES_GCM_IV_BYTES = 12;
    private static final int AES_GCM_TAG_BITS = 128;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final SecretKeySpec encryptionKey;

    public CryptoService(@Value("${encryption.card-encryption-key:}") String rawKey)
    {
        if (rawKey == null || rawKey.isEmpty()) {
            log.warn("CARD_ENCRYPTION_KEY not set — CryptoService will throw at runtime if used");
            this.encryptionKey = null;
        } else {
            this.encryptionKey = deriveKey(rawKey);
        }
    }

    public String encryptAESGCM(String plaintext)
    {
        checkKey();
        try {
            byte[] iv = new byte[AES_GCM_IV_BYTES];
            SECURE_RANDOM.nextBytes(iv);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec spec = new GCMParameterSpec(AES_GCM_TAG_BITS, iv);
            cipher.init(Cipher.ENCRYPT_MODE, encryptionKey, spec);

            byte[] encrypted = cipher.doFinal(plaintext.getBytes("UTF-8"));
            return ENCRYPTED_PREFIX + bytesToHex(iv) + bytesToHex(encrypted);
        } catch (Exception e) {
            throw new RuntimeException("AES-GCM encryption failed", e);
        }
    }

    public String decryptAESGCM(String ciphertext)
    {
        checkKey();
        if (!ciphertext.startsWith(ENCRYPTED_PREFIX)) {
            throw new IllegalArgumentException("Invalid encrypted data format: missing prefix");
        }
        try {
            String payload = ciphertext.substring(ENCRYPTED_PREFIX.length());
            byte[] iv = hexToBytes(payload.substring(0, AES_GCM_IV_BYTES * 2));
            byte[] encrypted = hexToBytes(payload.substring(AES_GCM_IV_BYTES * 2));

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec spec = new GCMParameterSpec(AES_GCM_TAG_BITS, iv);
            cipher.init(Cipher.DECRYPT_MODE, encryptionKey, spec);

            return new String(cipher.doFinal(encrypted), "UTF-8");
        } catch (Exception e) {
            throw new RuntimeException("AES-GCM decryption failed", e);
        }
    }

    public String safeExtractLast4(String encryptedCard)
    {
        try {
            return decryptAESGCM(encryptedCard).replaceAll("\\d+$", "");
        } catch (Exception e) {
            return null;
        }
    }

    private void checkKey()
    {
        if (encryptionKey == null) {
            throw new IllegalStateException("CARD_ENCRYPTION_KEY environment variable is not set");
        }
    }

    private SecretKeySpec deriveKey(String raw)
    {
        try {
            MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
            byte[] hash = sha256.digest(raw.getBytes("UTF-8"));
            return new SecretKeySpec(hash, "AES");
        } catch (Exception e) {
            throw new RuntimeException("Failed to derive encryption key", e);
        }
    }

    private String bytesToHex(byte[] bytes)
    {
        return HexFormat.of().formatHex(bytes);
    }

    private byte[] hexToBytes(String hex)
    {
        return HexFormat.of().parseHex(hex);
    }
}