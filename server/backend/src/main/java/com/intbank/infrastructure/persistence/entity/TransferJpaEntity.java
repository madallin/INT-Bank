package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "transfers")
public class TransferJpaEntity
{

    @Id
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "from_account_id", nullable = false)
    private AccountJpaEntity fromAccount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "to_account_id", nullable = false)
    private AccountJpaEntity toAccount;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(nullable = false)
    private String reason;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "initiated_at", nullable = false)
    private Instant initiatedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "failure_reason")
    private String failureReason;

    public String getId()
    {
        return id;
    }

    public void setId(String id)
    {
        this.id = id;
    }

    public AccountJpaEntity getFromAccount()
    {
        return fromAccount;
    }

    public void setFromAccount(AccountJpaEntity fromAccount)
    {
        this.fromAccount = fromAccount;
    }

    public String getFromAccountId()
    {
        return fromAccount != null ? String.valueOf(fromAccount.getId()) : null;
    }

    public AccountJpaEntity getToAccount()
    {
        return toAccount;
    }

    public void setToAccount(AccountJpaEntity toAccount)
    {
        this.toAccount = toAccount;
    }

    public String getToAccountId()
    {
        return toAccount != null ? String.valueOf(toAccount.getId()) : null;
    }

    public BigDecimal getAmount()
    {
        return amount;
    }

    public void setAmount(BigDecimal amount)
    {
        this.amount = amount;
    }

    public String getCurrency()
    {
        return currency;
    }

    public void setCurrency(String currency)
    {
        this.currency = currency;
    }

    public String getReason()
    {
        return reason;
    }

    public void setReason(String reason)
    {
        this.reason = reason;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public Instant getInitiatedAt()
    {
        return initiatedAt;
    }

    public void setInitiatedAt(Instant initiatedAt)
    {
        this.initiatedAt = initiatedAt;
    }

    public Instant getCompletedAt()
    {
        return completedAt;
    }

    public void setCompletedAt(Instant completedAt)
    {
        this.completedAt = completedAt;
    }

    public String getFailureReason()
    {
        return failureReason;
    }

    public void setFailureReason(String failureReason)
    {
        this.failureReason = failureReason;
    }
}