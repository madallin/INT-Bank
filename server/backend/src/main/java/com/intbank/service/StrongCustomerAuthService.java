package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.service.DynamicLinkingService.Payment;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Step-up authentication for payments at or above {@link #THRESHOLD}.
 *
 * <p>Two factors: possession (the signed-in device's session token) and knowledge (the PIN),
 * dynamically linked to the payment through a single-use challenge:
 * <ol>
 *   <li>The first request without proof is answered with {@link ScaRequiredException}
 *       carrying a challenge bound to this exact payment.</li>
 *   <li>The app shows those details and asks for the PIN.</li>
 *   <li>The retry carries the challenge id and PIN; both must match before money moves.</li>
 * </ol>
 */
@Service
public class StrongCustomerAuthService
{

    /** Amount (in the source account's currency) from which a payment needs the PIN again. */
    public static final BigDecimal THRESHOLD = new BigDecimal("1000.00");

    private final DynamicLinkingService dynamicLinking;
    private final PinVerificationService pinVerification;

    public StrongCustomerAuthService(DynamicLinkingService dynamicLinking, PinVerificationService pinVerification)
    {
        this.dynamicLinking = dynamicLinking;
        this.pinVerification = pinVerification;
    }

    public static boolean isRequired(BigDecimal amount)
    {
        return amount != null && amount.compareTo(THRESHOLD) >= 0;
    }

    /**
     * Returns normally when the payment may proceed; otherwise throws {@link ScaRequiredException}
     * (no proof yet) or {@link BusinessRuleException} (wrong PIN, locked PIN, stale challenge).
     */
    public void authorize(Payment payment, String challengeId, String pin)
    {
        if (!isRequired(payment.amount()))
        {
            return;
        }
        if (challengeId == null || challengeId.isBlank())
        {
            var challenge = dynamicLinking.createChallenge(payment);
            throw new ScaRequiredException(challenge.challengeId(), challenge.expiresAt(), payment);
        }

        dynamicLinking.requireMatchingChallenge(challengeId, payment);

        var result = pinVerification.verify(payment.userId(), pin);
        switch (result.outcome())
        {
            case OK -> dynamicLinking.consume(challengeId);
            case WRONG_PIN -> throw new BusinessRuleException(BusinessRuleException.SCA_PIN_INVALID,
                    "PIN incorect. Mai ai " + result.remainingAttempts() + " încercări.",
                    java.util.Map.of("remainingAttempts", result.remainingAttempts()));
            case LOCKED -> throw new BusinessRuleException(BusinessRuleException.SCA_LOCKED,
                    "PIN blocat temporar. Reîncearcă peste " + result.lockedMinutes() + " minute.");
            case NO_PIN -> throw new BusinessRuleException(BusinessRuleException.SCA_LOCKED,
                    "Setează un PIN înainte de a confirma plăți.");
        }
    }

    /** The payment needs the customer's PIN; carries the challenge the app must echo back. */
    public static class ScaRequiredException extends RuntimeException
    {
        public static final String CODE = "SCA_REQUIRED";

        private final String challengeId;
        private final Instant expiresAt;
        private final Payment payment;

        public ScaRequiredException(String challengeId, Instant expiresAt, Payment payment)
        {
            super("Confirmă plata cu PIN-ul");
            this.challengeId = challengeId;
            this.expiresAt = expiresAt;
            this.payment = payment;
        }

        public String challengeId()
        {
            return challengeId;
        }

        public Instant expiresAt()
        {
            return expiresAt;
        }

        public Payment payment()
        {
            return payment;
        }

        public java.util.Map<String, Object> toBody()
        {
            return java.util.Map.of(
                    "success", false,
                    "code", CODE,
                    "error", getMessage(),
                    "challengeId", challengeId,
                    "expiresAt", expiresAt.toString(),
                    "amount", payment.amount(),
                    "currency", payment.currency(),
                    "fromIban", payment.fromIban(),
                    "toIban", payment.toIban());
        }
    }
}
