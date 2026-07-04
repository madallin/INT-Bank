package com.intbank.core.domain.event;

import java.time.Instant;

public record TransferCompletedEvent(
    String trackingId,
    String fromAccountId,
    String toAccountId,
    String fromIban,
    String toIban,
    double amount,
    String currency,
    Instant completedAt
)
{
    public static final String EVENT_NAME = "transfer.completed";
}