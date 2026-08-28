package com.intbank.core.domain.event;

import java.math.BigDecimal;
import java.time.Instant;

public record TransferInitiatedEvent(
    String trackingId,
    String fromAccountId,
    String toAccountId,
    String fromIban,
    String toIban,
    BigDecimal amount,
    String currency,
    String description,
    Instant timestamp
)
{
    public static final String EVENT_NAME = "transfer.initiated";
}