package com.intbank.infrastructure.exception;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.service.DynamicLinkingService.Payment;
import com.intbank.service.StrongCustomerAuthService.ScaRequiredException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/** Every error reaches the client with a status that matches its meaning and no internals. */
class GlobalExceptionHandlerTest
{

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void businessRulesCarryTheirCodeAndDetails()
    {
        var response = handler.handleBusinessRule(new BusinessRuleException(
                BusinessRuleException.SCA_PIN_INVALID, "PIN incorect", Map.of("remainingAttempts", 1)));

        assertEquals(400, response.getStatusCode().value());
        assertEquals("SCA_PIN_INVALID", response.getBody().get("code"));
        assertEquals(1, response.getBody().get("remainingAttempts"));
    }

    @Test
    void aLockedPinIsReportedAsLocked()
    {
        var response = handler.handleBusinessRule(new BusinessRuleException(BusinessRuleException.SCA_LOCKED, "blocat"));
        assertEquals(423, response.getStatusCode().value());
    }

    @Test
    void stepUpIsAPreconditionNotAnError()
    {
        var response = handler.handleScaRequired(new ScaRequiredException("sca-1", Instant.now(),
                new Payment(1L, "A", "B", new BigDecimal("1000"), "RON")));
        assertEquals(428, response.getStatusCode().value());
        assertEquals("sca-1", response.getBody().get("challengeId"));
    }

    @Test
    void genericExceptionsMapToTheirStatus()
    {
        assertEquals(400, handler.handleIllegalArgument(new IllegalArgumentException("x")).getStatusCode().value());
        assertEquals(409, handler.handleIllegalState(new IllegalStateException("x")).getStatusCode().value());
        assertEquals(403, handler.handleSecurity(new SecurityException("x")).getStatusCode().value());

        var unexpected = handler.handleGeneric(new RuntimeException("jdbc:postgresql://db:5432 password=secret"));
        assertEquals(500, unexpected.getStatusCode().value());
        assertFalse(unexpected.getBody().toString().contains("password"), "internal details must not leak");
    }
}
