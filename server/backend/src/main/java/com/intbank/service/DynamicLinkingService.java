package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.infrastructure.persistence.entity.DynamicChallengeJpaEntity;
import com.intbank.infrastructure.persistence.repository.DynamicChallengeJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Dynamic linking: a step-up challenge is bound to one exact payment (customer, source and
 * destination account, amount, currency) and can be used once, within {@link #CHALLENGE_TTL}.
 */
@Service
public class DynamicLinkingService
{

    private static final Logger log = LoggerFactory.getLogger(DynamicLinkingService.class);
    public static final Duration CHALLENGE_TTL = Duration.ofMinutes(5);

    private final DynamicChallengeJpaRepository challengeRepo;
    private final SecretKeySpec signingKey;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Autowired
    public DynamicLinkingService(
            DynamicChallengeJpaRepository challengeRepo,
            @Value("${jwt.secret}") String secretRaw)
    {
        this(challengeRepo, secretRaw, Clock.systemUTC());
    }

    public DynamicLinkingService(DynamicChallengeJpaRepository challengeRepo, String secretRaw, Clock clock)
    {
        this.challengeRepo = challengeRepo;
        this.signingKey = new SecretKeySpec(secretRaw.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        this.clock = clock;
    }

    /** The payment a challenge authorizes. Amount is compared by value (100 == 100.00). */
    public record Payment(Long userId, String fromIban, String toIban, BigDecimal amount, String currency)
    {
    }

    public record ChallengeResponse(String challengeId, String signature, Instant expiresAt)
    {
    }

    public ChallengeResponse createChallenge(Payment payment)
    {
        String challengeId = "sca-" + UUID.randomUUID();
        Instant now = clock.instant();
        Instant expiresAt = now.plus(CHALLENGE_TTL);
        String signature = computeSignature(challengeId, payment);

        DynamicChallengeJpaEntity entity = new DynamicChallengeJpaEntity();
        entity.setChallengeId(challengeId);
        entity.setUserId(payment.userId());
        entity.setFromIban(payment.fromIban());
        entity.setToIban(payment.toIban());
        entity.setAmount(payment.amount());
        entity.setCurrency(payment.currency());
        entity.setStatus("PENDING");
        entity.setSignature(signature);
        entity.setCreatedAt(now);
        entity.setExpiresAt(expiresAt);
        challengeRepo.save(entity);

        log.info("SCA challenge {} issued to user {} for {} {} -> {}", challengeId, payment.userId(),
                payment.amount(), payment.currency(), payment.toIban());
        return new ChallengeResponse(challengeId, signature, expiresAt);
    }

    /**
     * Checks that {@code challengeId} is a live challenge issued for exactly this payment,
     * without using it up (a wrong PIN may be retried while the challenge is valid).
     */
    @Transactional(noRollbackFor = BusinessRuleException.class) // keep EXPIRED/TAMPERED
    public void requireMatchingChallenge(String challengeId, Payment payment)
    {
        var challenge = challengeRepo.findByChallengeIdAndStatus(challengeId, "PENDING")
                .orElseThrow(() -> invalid("Confirmarea a expirat sau a fost deja folosită. Reîncearcă plata."));

        if (!challenge.getUserId().equals(payment.userId()))
        {
            log.warn("SCA challenge {} presented by user {} but issued to {}", challengeId, payment.userId(), challenge.getUserId());
            throw invalid("Confirmarea nu corespunde acestei plăți.");
        }
        if (!challenge.getExpiresAt().isAfter(clock.instant()))
        {
            challenge.setStatus("EXPIRED");
            challengeRepo.save(challenge);
            throw invalid("Confirmarea a expirat. Reîncearcă plata.");
        }
        boolean matches = challenge.getAmount().compareTo(payment.amount()) == 0
                && challenge.getToIban().equals(payment.toIban())
                && payment.fromIban().equals(challenge.getFromIban())
                && payment.currency().equals(challenge.getCurrency());
        if (!matches)
        {
            // Payment details changed after the customer saw them: burn the challenge.
            challenge.setStatus("TAMPERED");
            challengeRepo.save(challenge);
            log.error("SCA challenge {} does not match the submitted payment", challengeId);
            throw invalid("Detaliile plății s-au schimbat după confirmare. Reîncearcă plata.");
        }
    }

    /** Marks the challenge used. Only one caller can win, so a challenge authorizes one payment. */
    @Transactional
    public void consume(String challengeId)
    {
        if (challengeRepo.transitionFromPending(challengeId, "VERIFIED") != 1)
        {
            throw invalid("Confirmarea a fost deja folosită.");
        }
    }

    private static BusinessRuleException invalid(String message)
    {
        return new BusinessRuleException(BusinessRuleException.SCA_CHALLENGE_INVALID, message);
    }

    private String computeSignature(String challengeId, Payment payment)
    {
        try
        {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(signingKey);
            String payload = String.join("|", challengeId, String.valueOf(payment.userId()), payment.fromIban(),
                    payment.toIban(), payment.amount().stripTrailingZeros().toPlainString(), payment.currency());
            return HexFormat.of().formatHex(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (Exception e)
        {
            throw new IllegalStateException("Failed to sign SCA challenge", e);
        }
    }
}
