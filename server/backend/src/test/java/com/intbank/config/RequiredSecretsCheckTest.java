package com.intbank.config;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class RequiredSecretsCheckTest
{

    private static final String STRONG = "3f9a1c7e5b2d8f604a1e9c3b7d5f2a8e";

    @Test
    void startsWithStrongSecrets()
    {
        assertDoesNotThrow(() -> new RequiredSecretsCheck(STRONG, STRONG));
    }

    @Test
    void refusesMissingShortOrPlaceholderSecrets()
    {
        assertThrows(IllegalStateException.class, () -> new RequiredSecretsCheck(STRONG, ""));
        assertThrows(IllegalStateException.class, () -> new RequiredSecretsCheck("", STRONG));
        assertThrows(IllegalStateException.class, () -> new RequiredSecretsCheck("short", STRONG));
        var error = assertThrows(IllegalStateException.class, () -> new RequiredSecretsCheck(null, null));
        assertTrue(error.getMessage().contains("JWT_SECRET"));
        assertTrue(error.getMessage().contains("CARD_ENCRYPTION_KEY"));
        assertFalse(error.getMessage().contains(STRONG), "secrets must never appear in the message");
    }
}
