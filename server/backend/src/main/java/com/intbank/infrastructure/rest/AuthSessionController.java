package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.service.TokenBlacklistService;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/auth-session")
public class AuthSessionController
{

    private static final Logger log = LoggerFactory.getLogger(AuthSessionController.class);
    private static final long ACCESS_TOKEN_TTL_MS = 300_000; // 5 minutes
    private static final long REFRESH_TOKEN_TTL_DAYS = 30;

    private final UserJpaRepository userRepo;
    private final RedisTemplate<String, String> redisTemplate;
    private final PasswordEncoder passwordEncoder;
    private final TokenBlacklistService tokenBlacklistService;
    private final com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthSessionController(
            UserJpaRepository userRepo,
            RedisTemplate<String, String> redisTemplate,
            PasswordEncoder passwordEncoder,
            TokenBlacklistService tokenBlacklistService,
            com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider)
    {
        this.userRepo = userRepo;
        this.redisTemplate = redisTemplate;
        this.passwordEncoder = passwordEncoder;
        this.tokenBlacklistService = tokenBlacklistService;
        this.rsaKeyProvider = rsaKeyProvider;
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> login(@RequestBody Map<String, String> body)
    {
        String phone = body.get("phone");
        String pin = body.get("pin");

        if (phone == null || phone.isBlank() || pin == null || pin.isBlank())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Numar de telefon si PIN necesare"));
        }

        var userOpt = userRepo.findByNrTelefon(phone);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Utilizator inexistent sau date invalide"));
        }

        UserJpaEntity user = userOpt.get();

        // Lockout check
        if (user.getPinLockedUntil() != null && user.getPinLockedUntil().isAfter(Instant.now()))
        {
            long remainingMinutes = java.time.Duration.between(Instant.now(), user.getPinLockedUntil()).toMinutes() + 1;
            return ResponseEntity.status(HttpStatus.LOCKED)
                    .body(Map.of("error", "Cont blocat temporar. Incearca peste " + remainingMinutes + " minute."));
        }

        if (user.getCodPin() == null || !passwordEncoder.matches(pin, user.getCodPin()))
        {
            int attempts = user.getPinFailedAttempts() + 1;
            user.setPinFailedAttempts(attempts);
            if (attempts >= 3)
            {
                user.setPinLockedUntil(Instant.now().plus(java.time.Duration.ofMinutes(15)));
                user.setPinFailedAttempts(0);
            }
            userRepo.save(user);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "PIN incorect", "remainingAttempts", Math.max(0, 3 - attempts)));
        }

        // Reset failed attempts on success
        user.setPinFailedAttempts(0);
        user.setPinLockedUntil(null);
        userRepo.save(user);

        // Generate Tokens
        String accessToken = generateAccessToken(user.getId(), phone, List.of("ROLE_USER"));
        String refreshToken = generateRefreshToken(user.getId(), phone);

        return ResponseEntity.ok(Map.of(
                "accessToken", accessToken,
                "refreshToken", refreshToken,
                "userId", user.getId(),
                "expiresIn", ACCESS_TOKEN_TTL_MS / 1000
        ));
    }

    @PostMapping("/refresh")
    public ResponseEntity<Map<String, Object>> refresh(@RequestBody Map<String, String> body)
    {
        String refreshToken = body.get("refreshToken");
        if (refreshToken == null || refreshToken.isBlank())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Refresh token lipsa"));
        }

        String redisKey = "session:refresh:" + refreshToken;
        String sessionData = redisTemplate.opsForValue().get(redisKey);
        if (sessionData == null)
        {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Sesiune expirata sau invalida"));
        }

        // Format in Redis: userId:phone
        String[] parts = sessionData.split(":");
        Long userId = Long.parseLong(parts[0]);
        String phone = parts.length > 1 ? parts[1] : "";

        // Rotate Refresh Token
        redisTemplate.delete(redisKey);
        String newRefreshToken = generateRefreshToken(userId, phone);
        String newAccessToken = generateAccessToken(userId, phone, List.of("ROLE_USER"));

        return ResponseEntity.ok(Map.of(
                "accessToken", newAccessToken,
                "refreshToken", newRefreshToken,
                "userId", userId,
                "expiresIn", ACCESS_TOKEN_TTL_MS / 1000
        ));
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, Object>> logout(
            @RequestHeader(value = "Authorization", required = false) String authHeader)
    {
        if (authHeader != null && authHeader.startsWith("Bearer "))
        {
            String token = authHeader.substring(7);
            tokenBlacklistService.blacklist(token, ACCESS_TOKEN_TTL_MS / 1000);
        }
        return ResponseEntity.ok(Map.of("success", true, "message", "Deconectat cu succes"));
    }

    private String generateAccessToken(Long userId, String subject, List<String> roles)
    {
        return Jwts.builder()
                .header().keyId(com.intbank.infrastructure.security.RsaKeyProvider.KEY_ID).and()
                .subject(subject)
                .claim("uid", userId)
                .claim("roles", roles)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + ACCESS_TOKEN_TTL_MS))
                .signWith(rsaKeyProvider.getPrivateKey())
                .compact();
    }

    private String generateRefreshToken(Long userId, String phone)
    {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        String refreshToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        redisTemplate.opsForValue().set("session:refresh:" + refreshToken, userId + ":" + phone, REFRESH_TOKEN_TTL_DAYS, TimeUnit.DAYS);
        return refreshToken;
    }
}
