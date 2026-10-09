package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.security.RsaKeyProvider;
import com.intbank.service.TokenBlacklistService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Phone + PIN sign-in, refresh-token rotation and sign-out. */
class AuthSessionControllerTest
{

    private static final String PHONE = "+40712345678";

    private final Map<String, String> redis = new HashMap<>();
    private final RsaKeyProvider keys = new RsaKeyProvider();
    private UserJpaEntity user;
    private UserJpaRepository userRepo;
    private TokenBlacklistService blacklist;
    private AuthSessionController controller;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp()
    {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
        user = new UserJpaEntity();
        user.setId(7L);
        user.setCodPin(encoder.encode("246802"));
        user.setPinFailedAttempts(0);
        userRepo = mock(UserJpaRepository.class);
        when(userRepo.findByNrTelefon(PHONE)).thenReturn(Optional.of(user));

        RedisTemplate<String, String> template = mock(RedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(template.opsForValue()).thenReturn(ops);
        doAnswer(i -> redis.put(i.getArgument(0), i.getArgument(1))).when(ops).set(anyString(), anyString(), anyLong(), any());
        when(ops.get(anyString())).thenAnswer(i -> redis.get((String) i.getArgument(0)));
        when(template.delete(anyString())).thenAnswer(i -> redis.remove((String) i.getArgument(0)) != null);

        blacklist = mock(TokenBlacklistService.class);
        controller = new AuthSessionController(userRepo, template, encoder, blacklist, keys);
    }

    @Test
    void correctPinIssuesAUserTokenSignedWithTheBankKey()
    {
        var response = controller.login(Map.of("phone", PHONE, "pin", "246802"));

        assertEquals(200, response.getStatusCode().value());
        Claims claims = Jwts.parser().verifyWith(keys.getPublicKey()).build()
                .parseSignedClaims((String) response.getBody().get("accessToken")).getPayload();
        assertEquals(7L, claims.get("uid", Long.class));
        assertEquals(List.of("ROLE_USER"), claims.get("roles", List.class));
        assertNotNull(response.getBody().get("refreshToken"));
    }

    @Test
    void threeWrongPinsLockSignInForFifteenMinutes()
    {
        assertEquals(401, controller.login(Map.of("phone", PHONE, "pin", "000000")).getStatusCode().value());
        assertEquals(401, controller.login(Map.of("phone", PHONE, "pin", "000000")).getStatusCode().value());
        assertEquals(401, controller.login(Map.of("phone", PHONE, "pin", "000000")).getStatusCode().value());

        assertNotNull(user.getPinLockedUntil());
        assertTrue(user.getPinLockedUntil().isAfter(Instant.now().plusSeconds(14 * 60)));
        assertEquals(423, controller.login(Map.of("phone", PHONE, "pin", "246802")).getStatusCode().value(),
                "the right PIN is refused while locked");
    }

    @Test
    void unknownPhoneAndMissingFieldsAreRejected()
    {
        assertEquals(401, controller.login(Map.of("phone", "+40700000000", "pin", "246802")).getStatusCode().value());
        assertEquals(400, controller.login(Map.of("phone", PHONE)).getStatusCode().value());
    }

    @Test
    void refreshRotatesTheTokenSoTheOldOneCannotBeReused()
    {
        String first = (String) controller.login(Map.of("phone", PHONE, "pin", "246802")).getBody().get("refreshToken");

        var refreshed = controller.refresh(Map.of("refreshToken", first));
        assertEquals(200, refreshed.getStatusCode().value());
        String second = (String) refreshed.getBody().get("refreshToken");
        assertNotEquals(first, second);

        assertEquals(401, controller.refresh(Map.of("refreshToken", first)).getStatusCode().value());
        assertEquals(200, controller.refresh(Map.of("refreshToken", second)).getStatusCode().value());
    }

    @Test
    void signOutRevokesTheAccessTokenAndEndsTheSession()
    {
        var session = controller.login(Map.of("phone", PHONE, "pin", "246802")).getBody();
        String token = (String) session.get("accessToken");
        String refresh = (String) session.get("refreshToken");

        controller.logout("Bearer " + token, Map.of("refreshToken", refresh));

        verify(blacklist).blacklist(eq(token), anyLong());
        assertEquals(401, controller.refresh(Map.of("refreshToken", refresh)).getStatusCode().value(),
                "a signed-out session cannot be refreshed");
    }

    @Test
    void signOutWithoutABodyStillWorks()
    {
        assertEquals(200, controller.logout(null, null).getStatusCode().value());
    }
}
