package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.DynamicChallengeJpaEntity;
import com.intbank.infrastructure.persistence.repository.DynamicChallengeJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

@Service
public class DynamicLinkingService
{

    private static final Logger log = LoggerFactory.getLogger(DynamicLinkingService.class);
    private static final Duration CHALLENGE_TTL = Duration.ofMinutes(5);

    private final DynamicChallengeJpaRepository challengeRepo;
    private final SecretKeySpec signingKey;

    public DynamicLinkingService(
            DynamicChallengeJpaRepository challengeRepo,
            @Value("${jwt.secret}") String secretRaw)
    {
        this.challengeRepo = challengeRepo;
        this.signingKey = new SecretKeySpec(secretRaw.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    public record ChallengeResponse(String challengeId, String signature, Instant expiresAt)
    {
    }

    public ChallengeResponse createChallenge(Long userId, BigDecimal amount, String toIban)
    {
        String challengeId = "sca-" + UUID.randomUUID().toString();
        Instant now = Instant.now();
        Instant expiresAt = now.plus(CHALLENGE_TTL);

        String signature = computeSignature(challengeId, amount, toIban);

        DynamicChallengeJpaEntity entity = new DynamicChallengeJpaEntity();
        entity.setChallengeId(challengeId);
        entity.setUserId(userId);
        entity.setAmount(amount);
        entity.setToIban(toIban);
        entity.setStatus("PENDING");
        entity.setSignature(signature);
        entity.setCreatedAt(now);
        entity.setExpiresAt(expiresAt);

        challengeRepo.save(entity);
        log.info("PSD2 Dynamic Linking challenge generated: id={}, user={}, toIban={}, amount={}",
                challengeId, userId, toIban, amount);

        return new ChallengeResponse(challengeId, signature, expiresAt);
    }

    public boolean verifyChallenge(String challengeId, BigDecimal amount, String toIban)
    {
        var opt = challengeRepo.findByChallengeIdAndStatus(challengeId, "PENDING");
        if (opt.isEmpty())
        {
            log.warn("Challenge {} not found or already verified", challengeId);
            return false;
        }

        DynamicChallengeJpaEntity challenge = opt.get();
        if (challenge.getExpiresAt().isBefore(Instant.now()))
        {
            challenge.setStatus("EXPIRED");
            challengeRepo.save(challenge);
            log.warn("Challenge {} has expired", challengeId);
            return false;
        }

        if (challenge.getAmount().compareTo(amount) != 0 || !challenge.getToIban().equals(toIban))
        {
            challenge.setStatus("TAMPERED");
            challengeRepo.save(challenge);
            log.error("PSD2 SCA Alert: Challenge details do not match! (Expected {} to {}, got {} to {})",
                    challenge.getAmount(), challenge.getToIban(), amount, toIban);
            return false;
        }

        challenge.setStatus("VERIFIED");
        challengeRepo.save(challenge);
        log.info("PSD2 Dynamic Linking challenge {} successfully verified", challengeId);
        return true;
    }

    private String computeSignature(String challengeId, BigDecimal amount, String toIban)
    {
        try
        {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(signingKey);
            String payload = challengeId + "|" + amount.toPlainString() + "|" + toIban;
            byte[] bytes = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        }
        catch (Exception e)
        {
            throw new RuntimeException("Failed to generate dynamic linking signature", e);
        }
    }
}
