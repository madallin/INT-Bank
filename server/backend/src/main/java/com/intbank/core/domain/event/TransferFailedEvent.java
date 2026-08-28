package com.intbank.core.domain.event;

import java.math.BigDecimal;
import java.time.Instant;

public record TransferFailedEvent(
    String trackingId,
    String fromAccountId,
    String toAccountId,
    String fromIban,
    String toIban,
    BigDecimal amount,
    String currency,
    String failureReason,
    Instant failedAt
)
{
    public static final String EVENT_NAME = "transfer.failed";
}