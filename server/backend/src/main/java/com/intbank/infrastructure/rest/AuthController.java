package com.intbank.infrastructure.rest;

import com.twilio.Twilio;
import com.twilio.rest.verify.v2.service.Verification;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.web.bind.annotation.*;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Date;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/auth")
public class AuthController
{

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);
    private final RedisTemplate<String, String> redisTemplate;
    private final SecretKey jwtSecret;
    private final String twilioServiceSid;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthController(
        RedisTemplate<String, String> redisTemplate,
        @Value("${jwt.secret}") String jwtSecretRaw,
        @Value("${twilio.account-sid}") String twilioAccountSid,
        @Value("${twilio.auth-token}") String twilioAuthToken,
        @Value("${twilio.service-sid}") String twilioServiceSid
    )
    {
        this.redisTemplate = redisTemplate;
        this.jwtSecret = Keys.hmacShaKeyFor(jwtSecretRaw.getBytes(StandardCharsets.UTF_8));
        this.twilioServiceSid = twilioServiceSid;
        Twilio.init(twilioAccountSid, twilioAuthToken);
    }

    @PostMapping("/get-client-token")
    public Map<String, Object> getClientToken(@RequestBody Map<String, String> body)
    {
        String deviceId = body.getOrDefault("deviceId", "dev-device");
        try {
            String clientToken = Jwts.builder()
                    .subject(deviceId)
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 300_000))
                    .signWith(jwtSecret)
                    .compact();

            byte[] refreshBytes = new byte[32];
            secureRandom.nextBytes(refreshBytes);
            String refreshToken = Base64.getUrlEncoder().withoutPadding().encodeToString(refreshBytes);

            redisTemplate.opsForValue().set("refresh:" + deviceId, refreshToken, 15, TimeUnit.MINUTES);

            return Map.of("client_token", clientToken, "refresh_token", refreshToken);
        } catch (Exception err) {
            log.error("Error generating client token", err);
            return Map.of("statusCode", 500, "error", "Server error generating token");
        }
    }

    @PostMapping("/refresh-client-token")
    public Map<String, Object> refreshClientToken(@RequestBody Map<String, String> body)
    {
        String deviceId = body.get("deviceId");
        String refreshToken = body.get("refreshToken");
        if (deviceId == null || refreshToken == null) {
            return Map.of("statusCode", 400, "error", "Missing parameters");
        }
        try {
            String stored = redisTemplate.opsForValue().get("refresh:" + deviceId);
            if (stored == null || !stored.equals(refreshToken)) {
                return Map.of("statusCode", 401, "error", "Invalid or expired refresh token");
            }
            String newToken = Jwts.builder()
                    .subject(deviceId)
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 300_000))
                    .signWith(jwtSecret)
                    .compact();
            return Map.of("client_token", newToken, "ttl", 300);
        } catch (Exception err) {
            log.error("Error refreshing client token", err);
            return Map.of("statusCode", 500, "error", "Server error");
        }
    }

    @PostMapping("/send-otp-sms")
    public Map<String, Object> sendOtpSms(@RequestBody Map<String, String> body)
    {
        String phone = body.get("phone");
        if (phone == null) {
            return Map.of("statusCode", 400, "error", "Numar de telefon lipsa");
        }

        String lastSentKey = "otp:sms:last:" + phone;
        String lastSent = redisTemplate.opsForValue().get(lastSentKey);
        if (lastSent != null && System.currentTimeMillis() - Long.parseLong(lastSent) < 60_000) {
            return Map.of("statusCode", 429, "error", "Asteapta 1 minut inainte de a solicita un nou cod");
        }

        try {
            Verification.creator(twilioServiceSid, phone, "sms").create();
            redisTemplate.opsForValue().set(lastSentKey, String.valueOf(System.currentTimeMillis()), 61, TimeUnit.SECONDS);
            return Map.of("success", true);
        } catch (Exception err) {
            log.error("Eroare la trimiterea SMS-ului OTP", err);
            return Map.of("statusCode", 500, "error", "Eroare la trimiterea SMS-ului");
        }
    }
}