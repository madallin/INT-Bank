package com.intbank.infrastructure.rest;

import com.twilio.Twilio;
import com.twilio.rest.verify.v2.service.Verification;
import com.twilio.rest.verify.v2.service.VerificationCheck;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/2fa")
public class TwoFAController
{

    private static final Logger log = LoggerFactory.getLogger(TwoFAController.class);
    private final RedisTemplate<String, String> redisTemplate;
    private final String twilioServiceSid;

    public TwoFAController(
        RedisTemplate<String, String> redisTemplate,
        @Value("${twilio.account-sid}") String twilioAccountSid,
        @Value("${twilio.auth-token}") String twilioAuthToken,
        @Value("${twilio.service-sid}") String twilioServiceSid
    )
    {
        this.redisTemplate = redisTemplate;
        this.twilioServiceSid = twilioServiceSid;
        Twilio.init(twilioAccountSid, twilioAuthToken);
    }

    @PostMapping("/request")
    public Map<String, Object> requestCode(@RequestBody Map<String, String> body)
    {
        String phone = body.get("phone");
        if (phone == null) {
            return Map.of("statusCode", 400, "error", "Numar de telefon lipsa");
        }

        String lastSentKey = "2fa:last:" + phone;
        String lastSent = redisTemplate.opsForValue().get(lastSentKey);
        if (lastSent != null && System.currentTimeMillis() - Long.parseLong(lastSent) < 60_000) {
            return Map.of("statusCode", 429, "error", "Asteapta 1 minut inainte de a retrimite codul");
        }

        try {
            Verification.creator(twilioServiceSid, phone, "sms").create();
            redisTemplate.opsForValue().set(lastSentKey, String.valueOf(System.currentTimeMillis()), 60, TimeUnit.SECONDS);
            return Map.of("success", true);
        } catch (Exception err) {
            log.error("Eroare la trimiterea SMS-ului", err);
            return Map.of("statusCode", 500, "error", "Eroare la trimiterea SMS-ului");
        }
    }

    @PostMapping("/verify")
    public Map<String, Object> verifyCode(@RequestBody Map<String, String> body)
    {
        String phone = body.get("phone");
        String code = body.get("code");
        if (phone == null || phone.length() <= 4 || code == null) {
            return Map.of("statusCode", 400, "error", "Parametri lipsa");
        }

        try {
            VerificationCheck check = VerificationCheck.creator(twilioServiceSid).setTo(phone).setCode(code).create();
            if ("approved".equals(check.getStatus())) {
                return Map.of("success", true, "status", check.getStatus());
            } else {
                return Map.of("statusCode", 400, "success", false, "status", check.getStatus());
            }
        } catch (Exception twErr) {
            log.error("Twilio verify error", twErr);
            String msg = twErr.getMessage();
            if (msg != null && msg.contains("60202")) {
                return Map.of("statusCode", 429, "error", "Ai depasit numarul maxim de incercari. Retrimite codul.");
            }
            if (msg != null && msg.contains("20404")) {
                return Map.of("statusCode", 400, "error", "Codul de verificare este invalid sau a expirat.");
            }
            return Map.of("statusCode", 500, "error", msg != null ? msg : "Eroare la verificarea codului");
        }
    }
}