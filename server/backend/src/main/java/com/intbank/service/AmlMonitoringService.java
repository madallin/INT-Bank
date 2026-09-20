package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class AmlMonitoringService
{

    private static final Logger log = LoggerFactory.getLogger(AmlMonitoringService.class);

    public static final int MAX_TRANSFERS_PER_MINUTE = 5;
    public static final int MIN_STRUCTURING_COUNT = 3;
    public static final Duration RAPID_MOVEMENT_WINDOW = Duration.ofMinutes(10);
    public static final Duration STRUCTURING_WINDOW = Duration.ofHours(24);
    public static final Duration VELOCITY_WINDOW = Duration.ofSeconds(60);
    public static final BigDecimal STRUCTURING_LOWER_BOUND = new BigDecimal("9000");
    public static final BigDecimal REPORTING_THRESHOLD = new BigDecimal("10000");
    public static final String EUR = "EUR";

    @FunctionalInterface
    public interface InstantSupplier
    {
        Instant now();
    }

    public enum AmlRiskAssessment
    {
        lowRisk,
        suspiciousFlagged,
        hardBlockRequired
    }

    public enum AmlIndicator
    {
        RAPID_MOVEMENT,
        STRUCTURING_SURFING,
        VELOCITY_SPIKE
    }

    public record AmlAssessmentResult(
            AmlRiskAssessment risk,
            Set<AmlIndicator> indicators,
            List<String> reasons,
            Instant evaluatedAt,
            String auditTrailMessage)
    {
    }

    public record AmlAuditEntry(
            String userId,
            BigDecimal amount,
            AmlRiskAssessment risk,
            Set<AmlIndicator> indicators,
            Instant timestamp,
            String detail)
    {
        public AmlAuditEntry(Long userId, BigDecimal amount, AmlRiskAssessment risk,
                             Set<AmlIndicator> indicators, Instant timestamp, String detail)
        {
            this(userId == null ? null : userId.toString(), amount, risk, indicators, timestamp, detail);
        }
    }

    private record DepositRecord(BigDecimal amount, Instant timestamp)
    {
    }

    private record TransferRecord(BigDecimal amount, String currency, Instant timestamp)
    {
    }

    private final InstantSupplier instantSupplier;
    private final int maxTransfersPerMinute;
    private final Map<Long, List<DepositRecord>> deposits = new ConcurrentHashMap<>();
    private final Map<Long, List<TransferRecord>> transfers = new ConcurrentHashMap<>();
    private final List<AmlAuditEntry> auditTrail = new CopyOnWriteArrayList<>();

    public AmlMonitoringService()
    {
        this(Instant::now);
    }

    AmlMonitoringService(InstantSupplier instantSupplier)
    {
        this(instantSupplier, MAX_TRANSFERS_PER_MINUTE);
    }

    AmlMonitoringService(InstantSupplier instantSupplier, int maxTransfersPerMinute)
    {
        this.instantSupplier = instantSupplier;
        this.maxTransfersPerMinute = maxTransfersPerMinute;
    }

    public void recordDeposit(Long userId, BigDecimal amount)
    {
        if (userId == null || amount == null)
        {
            return;
        }

        Instant now = instantSupplier.now();
        deposits.computeIfAbsent(userId, key -> new CopyOnWriteArrayList<>())
                .add(new DepositRecord(amount, now));
    }

    public AmlAssessmentResult evaluateTransfer(Long userId, BigDecimal amount, String currency, String toIban)
    {
        Instant now = instantSupplier.now();

        if (userId == null || amount == null)
        {
            String message = "AML evaluation skipped: missing userId or amount";
            auditTrail.add(new AmlAuditEntry(userId, amount, AmlRiskAssessment.lowRisk,
                    Set.of(), now, message));
            return new AmlAssessmentResult(AmlRiskAssessment.lowRisk, Set.of(), List.of(message), now, message);
        }

        String normalizedCurrency = currency == null ? "" : currency.toUpperCase(Locale.ROOT);
        List<TransferRecord> userTransfers = transfers.computeIfAbsent(userId, key -> new CopyOnWriteArrayList<>());
        userTransfers.add(new TransferRecord(amount, normalizedCurrency, now));

        Set<AmlIndicator> indicators = EnumSet.noneOf(AmlIndicator.class);
        List<String> reasons = new ArrayList<>();

        evaluateRapidMovement(userId, amount, now, indicators, reasons);

        if (EUR.equals(normalizedCurrency))
        {
            evaluateStructuring(userTransfers, now, indicators, reasons);
        }

        evaluateVelocity(userTransfers, now, indicators, reasons);

        AmlRiskAssessment risk = mapRisk(indicators);
        String auditTrailMessage = buildAuditMessage(userId, amount, normalizedCurrency, risk, indicators);
        auditTrail.add(new AmlAuditEntry(userId, amount, risk, Set.copyOf(indicators), now, auditTrailMessage));

        log.info("AML assessment for user {}: {} (indicators={})", userId, risk, indicators);

        return new AmlAssessmentResult(risk, Set.copyOf(indicators), List.copyOf(reasons), now, auditTrailMessage);
    }

    public List<AmlAuditEntry> getAuditTrail()
    {
        return List.copyOf(auditTrail);
    }

    public List<AmlAuditEntry> getAuditTrailForUser(Long userId)
    {
        String key = userId == null ? null : userId.toString();
        List<AmlAuditEntry> result = new ArrayList<>();
        for (AmlAuditEntry entry : auditTrail)
        {
            if (key != null && key.equals(entry.userId()))
            {
                result.add(entry);
            }
        }
        return List.copyOf(result);
    }

    public void reset(Long userId)
    {
        if (userId == null)
        {
            return;
        }

        deposits.remove(userId);
        transfers.remove(userId);
    }

    private void evaluateRapidMovement(Long userId, BigDecimal amount, Instant now,
                                       Set<AmlIndicator> indicators, List<String> reasons)
    {
        List<DepositRecord> userDeposits = deposits.get(userId);
        if (userDeposits == null)
        {
            return;
        }

        Instant cutoff = now.minus(RAPID_MOVEMENT_WINDOW);
        for (DepositRecord deposit : userDeposits)
        {
            boolean withinWindow = !deposit.timestamp().isBefore(cutoff) && !deposit.timestamp().isAfter(now);
            if (withinWindow && deposit.amount().compareTo(amount) >= 0)
            {
                indicators.add(AmlIndicator.RAPID_MOVEMENT);
                reasons.add("Inbound deposit of " + deposit.amount().toPlainString()
                        + " within 10 minutes covers the outgoing transfer of " + amount.toPlainString());
                return;
            }
        }
    }

    private void evaluateStructuring(List<TransferRecord> userTransfers, Instant now,
                                     Set<AmlIndicator> indicators, List<String> reasons)
    {
        Instant cutoff = now.minus(STRUCTURING_WINDOW);
        int count = 0;
        for (TransferRecord transfer : userTransfers)
        {
            boolean withinWindow = !transfer.timestamp().isBefore(cutoff) && !transfer.timestamp().isAfter(now);
            boolean justBelowThreshold = transfer.amount().compareTo(STRUCTURING_LOWER_BOUND) >= 0
                    && transfer.amount().compareTo(REPORTING_THRESHOLD) < 0;
            if (withinWindow && justBelowThreshold && EUR.equals(transfer.currency()))
            {
                count++;
            }
        }

        if (count >= MIN_STRUCTURING_COUNT)
        {
            indicators.add(AmlIndicator.STRUCTURING_SURFING);
            reasons.add("Detected " + count + " EUR transfers between " + STRUCTURING_LOWER_BOUND.toPlainString()
                    + " and " + REPORTING_THRESHOLD.toPlainString() + " within 24 hours");
        }
    }

    private void evaluateVelocity(List<TransferRecord> userTransfers, Instant now,
                                  Set<AmlIndicator> indicators, List<String> reasons)
    {
        Instant cutoff = now.minus(VELOCITY_WINDOW);
        int count = 0;
        for (TransferRecord transfer : userTransfers)
        {
            if (!transfer.timestamp().isBefore(cutoff) && !transfer.timestamp().isAfter(now))
            {
                count++;
            }
        }

        if (count > maxTransfersPerMinute)
        {
            indicators.add(AmlIndicator.VELOCITY_SPIKE);
            reasons.add("Detected " + count + " transfers within 60 seconds (limit "
                    + maxTransfersPerMinute + ")");
        }
    }

    private AmlRiskAssessment mapRisk(Set<AmlIndicator> indicators)
    {
        if (indicators.contains(AmlIndicator.VELOCITY_SPIKE) || indicators.size() >= 2)
        {
            return AmlRiskAssessment.hardBlockRequired;
        }

        if (indicators.size() == 1)
        {
            return AmlRiskAssessment.suspiciousFlagged;
        }

        return AmlRiskAssessment.lowRisk;
    }

    private String buildAuditMessage(Long userId, BigDecimal amount, String currency,
                                     AmlRiskAssessment risk, Set<AmlIndicator> indicators)
    {
        String indicatorText = indicators.isEmpty() ? "none" : indicators.toString();
        return "User " + userId + " transfer of " + amount.toPlainString() + " " + currency
                + " assessed as " + risk + " with indicators: " + indicatorText;
    }
}
