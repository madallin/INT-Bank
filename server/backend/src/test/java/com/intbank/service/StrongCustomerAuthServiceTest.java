package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.infrastructure.persistence.entity.DynamicChallengeJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.DynamicChallengeJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.service.DynamicLinkingService.Payment;
import com.intbank.service.StrongCustomerAuthService.ScaRequiredException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Step-up (PIN) confirmation for large payments, dynamically linked to the payment. */
class StrongCustomerAuthServiceTest
{

    private static final long USER = 7L;
    private static final String FROM = "RO49INTB0001RON0000000001";
    private static final String TO = "RO49INTB0001RON0000000002";
    private static final Payment LARGE = new Payment(USER, FROM, TO, new BigDecimal("1500.00"), "RON");

    private final Map<String, DynamicChallengeJpaEntity> challenges = new HashMap<>();
    private final MutableClock clock = new MutableClock(Instant.parse("2026-10-04T10:00:00Z"));
    private UserJpaEntity user;
    private StrongCustomerAuthService sca;

    @BeforeEach
    void setUp()
    {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
        user = new UserJpaEntity();
        user.setId(USER);
        user.setCodPin(encoder.encode("2468"));
        user.setPinFailedAttempts(0);
        UserJpaRepository userRepo = mock(UserJpaRepository.class);
        when(userRepo.findById(USER)).thenReturn(Optional.of(user));

        DynamicChallengeJpaRepository challengeRepo = mock(DynamicChallengeJpaRepository.class);
        when(challengeRepo.save(any())).thenAnswer(i -> {
            DynamicChallengeJpaEntity c = i.getArgument(0);
            challenges.put(c.getChallengeId(), c);
            return c;
        });
        when(challengeRepo.findByChallengeIdAndStatus(anyString(), anyString())).thenAnswer(i ->
                Optional.ofNullable(challenges.get((String) i.getArgument(0)))
                        .filter(c -> c.getStatus().equals(i.getArgument(1))));
        when(challengeRepo.transitionFromPending(anyString(), anyString())).thenAnswer(i -> {
            var c = challenges.get((String) i.getArgument(0));
            if (c == null || !"PENDING".equals(c.getStatus())) return 0;
            c.setStatus(i.getArgument(1));
            return 1;
        });

        sca = new StrongCustomerAuthService(
                new DynamicLinkingService(challengeRepo, "test-secret-test-secret-test-secret-0123", clock),
                new PinVerificationService(userRepo, encoder, clock));
    }

    @Test
    void smallPaymentsNeedNoStepUp()
    {
        assertDoesNotThrow(() -> sca.authorize(new Payment(USER, FROM, TO, new BigDecimal("999.99"), "RON"), null, null));
        assertTrue(challenges.isEmpty());
    }

    @Test
    void largePaymentWithoutProofGetsAChallengeBoundToThePayment()
    {
        ScaRequiredException required = assertThrows(ScaRequiredException.class, () -> sca.authorize(LARGE, null, null));

        var stored = challenges.get(required.challengeId());
        assertEquals("PENDING", stored.getStatus());
        assertEquals(USER, stored.getUserId());
        assertEquals(FROM, stored.getFromIban());
        assertEquals(TO, stored.getToIban());
        assertEquals("RON", stored.getCurrency());
        assertEquals(0, LARGE.amount().compareTo(stored.getAmount()));
        assertEquals("SCA_REQUIRED", required.toBody().get("code"));
    }

    @Test
    void correctPinAuthorizesOnceOnly()
    {
        String id = challenge();

        assertDoesNotThrow(() -> sca.authorize(LARGE, id, "2468"));
        assertEquals("VERIFIED", challenges.get(id).getStatus());

        var replay = assertThrows(BusinessRuleException.class, () -> sca.authorize(LARGE, id, "2468"));
        assertEquals(BusinessRuleException.SCA_CHALLENGE_INVALID, replay.code());
    }

    @Test
    void wrongPinKeepsTheChallengeUsableAndCountsTowardsLockout()
    {
        String id = challenge();

        var wrong = assertThrows(BusinessRuleException.class, () -> sca.authorize(LARGE, id, "0000"));
        assertEquals(BusinessRuleException.SCA_PIN_INVALID, wrong.code());
        assertTrue(wrong.getMessage().contains("2"));
        assertEquals("PENDING", challenges.get(id).getStatus());

        assertDoesNotThrow(() -> sca.authorize(LARGE, id, "2468"));
        assertEquals(0, user.getPinFailedAttempts());
    }

    @Test
    void threeWrongPinsLockTheCustomerEvenWithTheRightPinAfterwards()
    {
        String id = challenge();
        sca(id, "1111");
        sca(id, "2222");
        assertEquals(BusinessRuleException.SCA_LOCKED, sca(id, "3333").code());
        assertEquals(BusinessRuleException.SCA_LOCKED, sca(id, "2468").code());
        assertNotNull(user.getPinLockedUntil());

        clock.advance(PinVerificationService.LOCKOUT.plusSeconds(1));
        String fresh = challenge();
        assertDoesNotThrow(() -> sca.authorize(LARGE, fresh, "2468"));
    }

    @Test
    void anyChangeToThePaymentAfterTheChallengeBurnsIt()
    {
        for (Payment changed : new Payment[]{
                new Payment(USER, FROM, TO, new BigDecimal("1500.01"), "RON"),
                new Payment(USER, FROM, "RO49INTB0001RON0000000099", LARGE.amount(), "RON"),
                new Payment(USER, "RO49INTB0001RON0000000077", TO, LARGE.amount(), "RON"),
                new Payment(USER, FROM, TO, LARGE.amount(), "EUR")})
        {
            String id = challenge();
            var error = assertThrows(BusinessRuleException.class, () -> sca.authorize(changed, id, "2468"));
            assertEquals(BusinessRuleException.SCA_CHALLENGE_INVALID, error.code());
            assertEquals("TAMPERED", challenges.get(id).getStatus());
        }
        assertEquals(0, user.getPinFailedAttempts(), "PIN is not checked for a mismatching payment");
    }

    @Test
    void amountsAreComparedByValue()
    {
        String id = challenge();
        assertDoesNotThrow(() -> sca.authorize(new Payment(USER, FROM, TO, new BigDecimal("1500"), "RON"), id, "2468"));
    }

    @Test
    void anotherCustomersChallengeIsRejected()
    {
        String id = challenge();
        var error = assertThrows(BusinessRuleException.class,
                () -> sca.authorize(new Payment(99L, FROM, TO, LARGE.amount(), "RON"), id, "2468"));
        assertEquals(BusinessRuleException.SCA_CHALLENGE_INVALID, error.code());
        assertEquals("PENDING", challenges.get(id).getStatus());
    }

    @Test
    void expiredChallengeIsRejected()
    {
        String id = challenge();
        clock.advance(DynamicLinkingService.CHALLENGE_TTL);

        var error = assertThrows(BusinessRuleException.class, () -> sca.authorize(LARGE, id, "2468"));
        assertEquals(BusinessRuleException.SCA_CHALLENGE_INVALID, error.code());
        assertEquals("EXPIRED", challenges.get(id).getStatus());
    }

    private String challenge()
    {
        return assertThrows(ScaRequiredException.class, () -> sca.authorize(LARGE, null, null)).challengeId();
    }

    private BusinessRuleException sca(String id, String pin)
    {
        return assertThrows(BusinessRuleException.class, () -> sca.authorize(LARGE, id, pin));
    }

    private static final class MutableClock extends Clock
    {
        private Instant now;

        MutableClock(Instant now)
        {
            this.now = now;
        }

        void advance(Duration duration)
        {
            now = now.plus(duration);
        }

        @Override
        public Instant instant()
        {
            return now;
        }

        @Override
        public java.time.ZoneId getZone()
        {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone)
        {
            return this;
        }
    }
}
