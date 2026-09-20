package com.intbank.infrastructure.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.security.*;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.util.Base64;
import java.util.List;
import java.util.Map;

@Component
public class RsaKeyProvider
{

    private static final Logger log = LoggerFactory.getLogger(RsaKeyProvider.class);
    public static final String KEY_ID = "intbank-rsa-key-1";

    private final RSAPrivateKey privateKey;
    private final RSAPublicKey publicKey;

    public RsaKeyProvider()
    {
        try
        {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            KeyPair keyPair = generator.generateKeyPair();
            this.privateKey = (RSAPrivateKey) keyPair.getPrivate();
            this.publicKey = (RSAPublicKey) keyPair.getPublic();
            log.info("Initialized ephemeral RSA-2048 keypair for RS256 JWT signing and JWKS");
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Failed to initialize RSA keypair", e);
        }
    }

    public RSAPrivateKey getPrivateKey()
    {
        return privateKey;
    }

    public RSAPublicKey getPublicKey()
    {
        return publicKey;
    }

    public Map<String, Object> getJwks()
    {
        String n = Base64.getUrlEncoder().withoutPadding().encodeToString(publicKey.getModulus().toByteArray());
        String e = Base64.getUrlEncoder().withoutPadding().encodeToString(publicKey.getPublicExponent().toByteArray());

        Map<String, Object> jwk = Map.of(
                "kty", "RSA",
                "use", "sig",
                "alg", "RS256",
                "kid", KEY_ID,
                "n", n,
                "e", e
        );

        return Map.of("keys", List.of(jwk));
    }
}
