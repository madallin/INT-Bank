package com.intbank.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Refuses to start the server without the secrets it cannot work safely without, instead of
 * failing later (a missing card key used to surface only when a customer was approved).
 */
@Component
public class RequiredSecretsCheck
{

    private static final Set<String> PLACEHOLDERS = Set.of("secret", "changeme", "change-me", "admin", "password", "test");

    public RequiredSecretsCheck(@Value("${jwt.secret:}") String jwtSecret,
                                @Value("${encryption.card-encryption-key:}") String cardEncryptionKey)
    {
        List<String> problems = problems(jwtSecret, cardEncryptionKey);
        if (!problems.isEmpty())
        {
            throw new IllegalStateException("Missing or weak secrets: " + String.join("; ", problems)
                    + ". Set them in server/.env (Compose) or the Helm secrets. Generate one with: openssl rand -hex 32");
        }
    }

    static List<String> problems(String jwtSecret, String cardEncryptionKey)
    {
        List<String> problems = new ArrayList<>();
        if (isWeak(jwtSecret))
        {
            problems.add("JWT_SECRET must be at least 32 bytes and not a placeholder");
        }
        if (isWeak(cardEncryptionKey))
        {
            problems.add("CARD_ENCRYPTION_KEY must be at least 32 bytes and not a placeholder");
        }
        return problems;
    }

    private static boolean isWeak(String value)
    {
        return value == null
                || value.getBytes(StandardCharsets.UTF_8).length < 32
                || PLACEHOLDERS.contains(value.trim().toLowerCase());
    }
}
