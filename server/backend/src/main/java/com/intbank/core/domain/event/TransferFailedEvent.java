package com.intbank.core.domain.event;

import java.time.Instant;

public record TransferFailedEvent(
    String trackingId,
    String fromAccountId,
    String toAccountId,
    String fromIban,
    String toIban,
    double amount,
    String currency,
    String failureReason,
    Instant failedAt
)
{
    public static final String EVENT_NAME = "transfer.failed";
}