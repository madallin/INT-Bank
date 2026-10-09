package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.security.RsaKeyProvider;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PreAuthTokenServiceTest
{

    private final RsaKeyProvider keys = new RsaKeyProvider();

    @Test
    void aVerifiedPhoneGetsAShortLivedOnboardingTokenAndItsState()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(7L);
        user.setTermeniAcceptati(true);
        user.setContAprobat(false);
        UserJpaRepository repo = mock(UserJpaRepository.class);
        when(repo.findByNrTelefon("+40712345678")).thenReturn(Optional.of(user));

        var result = new PreAuthTokenService(repo, keys).issueForVerifiedPhone("+40712345678").orElseThrow();

        Claims claims = Jwts.parser().verifyWith(keys.getPublicKey()).build()
                .parseSignedClaims((String) result.get("preAuthToken")).getPayload();
        assertEquals(7L, claims.get("uid", Long.class));
        assertEquals(List.of(PreAuthTokenService.ROLE), claims.get("roles", List.class), "never ROLE_USER");
        long lifetime = claims.getExpiration().getTime() - claims.getIssuedAt().getTime();
        assertEquals(PreAuthTokenService.TTL.toMillis(), lifetime);

        assertEquals(7L, result.get("userId"));
        assertEquals(true, result.get("acceptedTerms"));
        assertEquals(false, result.get("approved"));
        assertEquals(false, result.get("hasPin"));
    }

    @Test
    void anUnknownPhoneGetsNothing()
    {
        UserJpaRepository repo = mock(UserJpaRepository.class);
        when(repo.findByNrTelefon("+40700000000")).thenReturn(Optional.empty());
        assertTrue(new PreAuthTokenService(repo, keys).issueForVerifiedPhone("+40700000000").isEmpty());
    }
}
