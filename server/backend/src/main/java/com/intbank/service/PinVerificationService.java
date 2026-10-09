package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

/**
 * Checks a customer's PIN with the same lockout the sign-in uses: three wrong PINs lock
 * the PIN for 15 minutes. Attempts are counted on the user record, so wrong PINs at sign-in
 * and at payment confirmation add up.
 */
@Service
public class PinVerificationService
{

    public static final int MAX_ATTEMPTS = 3;
    public static final Duration LOCKOUT = Duration.ofMinutes(15);

    private final UserJpaRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Autowired
    public PinVerificationService(UserJpaRepository userRepo, PasswordEncoder passwordEncoder)
    {
        this(userRepo, passwordEncoder, Clock.systemUTC());
    }

    public PinVerificationService(UserJpaRepository userRepo, PasswordEncoder passwordEncoder, Clock clock)
    {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
    }

    public enum Outcome { OK, WRONG_PIN, LOCKED, NO_PIN }

    /** {@code remainingAttempts} is set for WRONG_PIN; {@code lockedMinutes} for LOCKED. */
    public record Result(Outcome outcome, int remainingAttempts, long lockedMinutes)
    {
        public boolean ok()
        {
            return outcome == Outcome.OK;
        }
    }

    @Transactional
    public Result verify(Long userId, String pin)
    {
        UserJpaEntity user = userRepo.findById(userId).orElse(null);
        if (user == null || user.getCodPin() == null)
        {
            return new Result(Outcome.NO_PIN, 0, 0);
        }

        Instant now = clock.instant();
        if (user.getPinLockedUntil() != null && user.getPinLockedUntil().isAfter(now))
        {
            return new Result(Outcome.LOCKED, 0, Duration.between(now, user.getPinLockedUntil()).toMinutes() + 1);
        }

        if (pin == null || pin.isBlank() || !passwordEncoder.matches(pin, user.getCodPin()))
        {
            int attempts = (user.getPinFailedAttempts() == null ? 0 : user.getPinFailedAttempts()) + 1;
            if (attempts >= MAX_ATTEMPTS)
            {
                user.setPinLockedUntil(now.plus(LOCKOUT));
                user.setPinFailedAttempts(0);
                userRepo.save(user);
                return new Result(Outcome.LOCKED, 0, LOCKOUT.toMinutes());
            }
            user.setPinFailedAttempts(attempts);
            userRepo.save(user);
            return new Result(Outcome.WRONG_PIN, MAX_ATTEMPTS - attempts, 0);
        }

        user.setPinFailedAttempts(0);
        user.setPinLockedUntil(null);
        userRepo.save(user);
        return new Result(Outcome.OK, MAX_ATTEMPTS, 0);
    }
}
