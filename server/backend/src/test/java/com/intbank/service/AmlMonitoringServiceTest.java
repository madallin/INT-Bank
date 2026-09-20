package com.intbank.service;

import com.intbank.service.AmlMonitoringService.AmlAssessmentResult;
import com.intbank.service.AmlMonitoringService.AmlAuditEntry;
import com.intbank.service.AmlMonitoringService.AmlIndicator;
import com.intbank.service.AmlMonitoringService.AmlRiskAssessment;
import com.intbank.service.AmlMonitoringService.InstantSupplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AmlMonitoringServiceTest
{

    private static final String IBAN = "DE89370400440532013000";

    private Instant now;
    private AmlMonitoringService service;

    @BeforeEach
    void setUp()
    {
        now = Instant.parse("2026-01-01T00:00:00Z");
        InstantSupplier supplier = () -> now;
        service = new AmlMonitoringService(supplier);
    }

    @Test
    void legitimateSingleTransactionIsLowRisk()
    {
        AmlAssessmentResult result = service.evaluateTransfer(1L, new BigDecimal("100.00"), "EUR", IBAN);

        assertEquals(AmlRiskAssessment.lowRisk, result.risk());
        assertTrue(result.indicators().isEmpty());
        assertEquals(now, result.evaluatedAt());
        assertNotNull(result.auditTrailMessage());
        assertEquals(1, service.getAuditTrail().size());
        assertEquals(1, service.getAuditTrailForUser(1L).size());
    }

    @Test
    void structuringDetectedForThreeJustBelowThresholdTransfers()
    {
        AmlAssessmentResult result = null;
        for (int i = 0; i < 3; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("9500.00"), "EUR", IBAN);
            now = now.plusSeconds(1);
        }

        assertNotNull(result);
        assertTrue(result.indicators().contains(AmlIndicator.STRUCTURING_SURFING));
        assertFalse(result.indicators().contains(AmlIndicator.VELOCITY_SPIKE));
        assertEquals(AmlRiskAssessment.suspiciousFlagged, result.risk());
    }

    @Test
    void transfersAtReportingThresholdDoNotTriggerStructuring()
    {
        AmlAssessmentResult result = null;
        for (int i = 0; i < 3; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("10000.00"), "EUR", IBAN);
            now = now.plusSeconds(1);
        }

        assertNotNull(result);
        assertFalse(result.indicators().contains(AmlIndicator.STRUCTURING_SURFING));
        assertEquals(AmlRiskAssessment.lowRisk, result.risk());
    }

    @Test
    void velocitySpikeTriggersHardBlockForSixTransfers()
    {
        AmlAssessmentResult result = null;
        for (int i = 0; i < 6; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("100.00"), "EUR", IBAN);
            now = now.plusSeconds(5);
        }

        assertNotNull(result);
        assertTrue(result.indicators().contains(AmlIndicator.VELOCITY_SPIKE));
        assertEquals(AmlRiskAssessment.hardBlockRequired, result.risk());
    }

    @Test
    void fiveTransfersDoNotTriggerVelocitySpike()
    {
        AmlAssessmentResult result = null;
        for (int i = 0; i < 5; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("100.00"), "EUR", IBAN);
            now = now.plusSeconds(5);
        }

        assertNotNull(result);
        assertFalse(result.indicators().contains(AmlIndicator.VELOCITY_SPIKE));
        assertEquals(AmlRiskAssessment.lowRisk, result.risk());
    }

    @Test
    void rapidMovementDetectedForRecentLargeDeposit()
    {
        service.recordDeposit(1L, new BigDecimal("50000.00"));
        now = now.plusSeconds(60);

        AmlAssessmentResult result = service.evaluateTransfer(1L, new BigDecimal("20000.00"), "EUR", IBAN);

        assertTrue(result.indicators().contains(AmlIndicator.RAPID_MOVEMENT));
        assertEquals(AmlRiskAssessment.suspiciousFlagged, result.risk());
    }

    @Test
    void rapidMovementNotDetectedForExpiredDeposit()
    {
        service.recordDeposit(1L, new BigDecimal("50000.00"));
        now = now.plusSeconds(601);

        AmlAssessmentResult result = service.evaluateTransfer(1L, new BigDecimal("20000.00"), "EUR", IBAN);

        assertFalse(result.indicators().contains(AmlIndicator.RAPID_MOVEMENT));
        assertEquals(AmlRiskAssessment.lowRisk, result.risk());
    }

    @Test
    void combinedIndicatorsRequireHardBlock()
    {
        service.recordDeposit(1L, new BigDecimal("50000.00"));
        now = now.plusSeconds(60);

        AmlAssessmentResult result = null;
        for (int i = 0; i < 3; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("9500.00"), "EUR", IBAN);
            now = now.plusSeconds(5);
        }

        assertNotNull(result);
        assertTrue(result.indicators().contains(AmlIndicator.RAPID_MOVEMENT));
        assertTrue(result.indicators().contains(AmlIndicator.STRUCTURING_SURFING));
        assertEquals(AmlRiskAssessment.hardBlockRequired, result.risk());
    }

    @Test
    void auditTrailHasDeterministicTimestampsAndFiltersPerUser()
    {
        AmlAssessmentResult first = service.evaluateTransfer(1L, new BigDecimal("100.00"), "EUR", IBAN);
        now = now.plusSeconds(10);
        AmlAssessmentResult second = service.evaluateTransfer(2L, new BigDecimal("200.00"), "EUR", IBAN);

        List<AmlAuditEntry> all = service.getAuditTrail();
        assertEquals(2, all.size());
        assertEquals(Instant.parse("2026-01-01T00:00:00Z"), all.get(0).timestamp());
        assertEquals(Instant.parse("2026-01-01T00:00:10Z"), all.get(1).timestamp());
        assertEquals(first.evaluatedAt(), all.get(0).timestamp());
        assertEquals(second.evaluatedAt(), all.get(1).timestamp());
        assertEquals("1", all.get(0).userId());
        assertEquals("2", all.get(1).userId());
        assertEquals(1, service.getAuditTrailForUser(1L).size());
        assertEquals(1, service.getAuditTrailForUser(2L).size());
        assertEquals(0, service.getAuditTrailForUser(3L).size());
    }

    @Test
    void userActivityIsIsolated()
    {
        for (int i = 0; i < 3; i++)
        {
            service.evaluateTransfer(1L, new BigDecimal("9500.00"), "EUR", IBAN);
            now = now.plusSeconds(1);
        }

        AmlAssessmentResult other = service.evaluateTransfer(2L, new BigDecimal("100.00"), "EUR", IBAN);

        assertEquals(AmlRiskAssessment.lowRisk, other.risk());
        assertTrue(other.indicators().isEmpty());
    }

    @Test
    void nonEurTransfersDoNotTriggerStructuring()
    {
        AmlAssessmentResult result = null;
        for (int i = 0; i < 3; i++)
        {
            result = service.evaluateTransfer(1L, new BigDecimal("9500.00"), "USD", IBAN);
            now = now.plusSeconds(1);
        }

        assertNotNull(result);
        assertFalse(result.indicators().contains(AmlIndicator.STRUCTURING_SURFING));
        assertEquals(AmlRiskAssessment.lowRisk, result.risk());
    }

    @Test
    void resetClearsRecordedActivity()
    {
        for (int i = 0; i < 3; i++)
        {
            service.evaluateTransfer(1L, new BigDecimal("9500.00"), "EUR", IBAN);
            now = now.plusSeconds(1);
        }

        service.reset(1L);

        AmlAssessmentResult afterReset = service.evaluateTransfer(1L, new BigDecimal("9500.00"), "EUR", IBAN);

        assertFalse(afterReset.indicators().contains(AmlIndicator.STRUCTURING_SURFING));
        assertEquals(AmlRiskAssessment.lowRisk, afterReset.risk());
    }
}
