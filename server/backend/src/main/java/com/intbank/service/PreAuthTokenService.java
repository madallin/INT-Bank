package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.security.RsaKeyProvider;
import io.jsonwebtoken.Jwts;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Issues the short-lived token a customer gets after proving they own their phone (SMS code).
 *
 * <p>It names the customer ({@code uid}) but carries only {@link #ROLE}, which the security
 * configuration accepts on the onboarding endpoints alone: reading terms/approval/PIN status,
 * accepting the terms and choosing the first PIN. Everything else needs the full session token
 * from phone + PIN sign-in.
 */
@Service
public class PreAuthTokenService
{

    public static final String ROLE = "ROLE_PREAUTH";
    public static final Duration TTL = Duration.ofMinutes(15);

    private final UserJpaRepository userRepo;
    private final RsaKeyProvider keys;
    private final Clock clock;

    @Autowired
    public PreAuthTokenService(UserJpaRepository userRepo, RsaKeyProvider keys)
    {
        this(userRepo, keys, Clock.systemUTC());
    }

    public PreAuthTokenService(UserJpaRepository userRepo, RsaKeyProvider keys, Clock clock)
    {
        this.userRepo = userRepo;
        this.keys = keys;
        this.clock = clock;
    }

    /**
     * For a phone number that has just been verified by SMS: the token plus the onboarding state
     * the app needs to choose the next screen. Empty when no customer has this number.
     */
    public Optional<Map<String, Object>> issueForVerifiedPhone(String phone)
    {
        return userRepo.findByNrTelefon(phone).map(user -> {
            Instant now = clock.instant();
            String token = Jwts.builder()
                    .header().keyId(RsaKeyProvider.KEY_ID).and()
                    .subject(phone)
                    .claim("uid", user.getId())
                    .claim("roles", List.of(ROLE))
                    .issuedAt(Date.from(now))
                    .expiration(Date.from(now.plus(TTL)))
                    .signWith(keys.getPrivateKey())
                    .compact();

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("preAuthToken", token);
            result.put("expiresIn", TTL.toSeconds());
            result.put("userId", user.getId());
            result.put("acceptedTerms", Boolean.TRUE.equals(user.getTermeniAcceptati()));
            result.put("approved", Boolean.TRUE.equals(user.getContAprobat()));
            result.put("hasPin", hasPin(user));
            return result;
        });
    }

    private static boolean hasPin(UserJpaEntity user)
    {
        return user.getCodPin() != null && !user.getCodPin().isBlank();
    }
}
