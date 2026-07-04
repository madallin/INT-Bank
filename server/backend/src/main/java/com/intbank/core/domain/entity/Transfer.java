package com.intbank.core.domain.entity;

import com.intbank.core.domain.vo.TransferStatus;

import java.time.Instant;
import java.util.Objects;

public class Transfer
{

    private final String id;
    private final String fromAccountId;
    private final String toAccountId;
    private final double amount;
    private final String currency;
    private final String reason;
    private TransferStatus status;
    private final Instant initiatedAt;
    private Instant completedAt;
    private String failureReason;

    public Transfer(
        String id,
        String fromAccountId,
        String toAccountId,
        double amount,
        String currency,
        String reason,
        Instant initiatedAt
    )
    {
        this.id = id;
        this.fromAccountId = fromAccountId;
        this.toAccountId = toAccountId;
        this.amount = amount;
        this.currency = currency;
        this.reason = reason;
        this.status = TransferStatus.PENDING;
        this.initiatedAt = initiatedAt;
    }

    public void complete(Instant completedAt)
    {
        if (!TransferStatus.isValidTransition(this.status, TransferStatus.COMPLETED))
        {
            throw new IllegalStateException("Cannot complete transfer in state: " + status);
        }
        this.status = TransferStatus.COMPLETED;
        this.completedAt = completedAt;
    }

    public void fail(String reason, Instant failedAt)
    {
        if (!TransferStatus.isValidTransition(this.status, TransferStatus.FAILED))
        {
            throw new IllegalStateException("Cannot fail transfer in state: " + status);
        }
        this.status = TransferStatus.FAILED;
        this.failureReason = reason;
        this.completedAt = failedAt;
    }

    public String id() { return id; }
    public String fromAccountId() { return fromAccountId; }
    public String toAccountId() { return toAccountId; }
    public double amount() { return amount; }
    public String currency() { return currency; }
    public String reason() { return reason; }
    public TransferStatus status() { return status; }
    public Instant initiatedAt() { return initiatedAt; }
    public Instant completedAt() { return completedAt; }
    public String failureReason() { return failureReason; }

    @Override
    public boolean equals(Object o)
    {
        if (this == o) { return true; }
        if (!(o instanceof Transfer transfer)) { return false; }
        return Objects.equals(id, transfer.id);
    }

    @Override
    public int hashCode() { return Objects.hash(id); }
}