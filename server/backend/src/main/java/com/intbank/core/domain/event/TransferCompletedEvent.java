package com.intbank.core.domain.event;

import java.math.BigDecimal;
import java.time.Instant;

public record TransferCompletedEvent(
    String trackingId,
    String fromAccountId,
    String toAccountId,
    String fromIban,
    String toIban,
    BigDecimal amount,
    String currency,
    Instant completedAt
)
{
    public static final String EVENT_NAME = "transfer.completed";
}