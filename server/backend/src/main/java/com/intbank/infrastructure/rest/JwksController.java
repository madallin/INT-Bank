package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.security.RsaKeyProvider;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class JwksController
{

    private final RsaKeyProvider rsaKeyProvider;

    public JwksController(RsaKeyProvider rsaKeyProvider)
    {
        this.rsaKeyProvider = rsaKeyProvider;
    }

    @GetMapping(value = "/.well-known/jwks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> getJwks()
    {
        return ResponseEntity.ok(rsaKeyProvider.getJwks());
    }
}
