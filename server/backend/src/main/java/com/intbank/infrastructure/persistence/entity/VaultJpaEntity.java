package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

/** A savings goal; its money lives in its own SAVINGS account ({@link #accountId}). */
@Entity
@Table(name = "vaults")
public class VaultJpaEntity
{

    public static final String FLEXIBLE = "FLEXIBLE";
    public static final String LOCKED = "LOCKED";
    public static final String ACTIVE = "ACTIVE";
    public static final String CLOSED = "CLOSED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "account_id", nullable = false, unique = true)
    private Long accountId;

    @Column(nullable = false, length = 60)
    private String name;

    @Column(name = "target_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal targetAmount;

    @Column(name = "target_date")
    private LocalDate targetDate;

    @Column(name = "lock_type", nullable = false, length = 16)
    private String lockType = FLEXIBLE;

    @Column(nullable = false, length = 16)
    private String status = ACTIVE;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "closed_at")
    private Instant closedAt;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getUserId()
    {
        return userId;
    }

    public void setUserId(Long userId)
    {
        this.userId = userId;
    }

    public Long getAccountId()
    {
        return accountId;
    }

    public void setAccountId(Long accountId)
    {
        this.accountId = accountId;
    }

    public String getName()
    {
        return name;
    }

    public void setName(String name)
    {
        this.name = name;
    }

    public BigDecimal getTargetAmount()
    {
        return targetAmount;
    }

    public void setTargetAmount(BigDecimal targetAmount)
    {
        this.targetAmount = targetAmount;
    }

    public LocalDate getTargetDate()
    {
        return targetDate;
    }

    public void setTargetDate(LocalDate targetDate)
    {
        this.targetDate = targetDate;
    }

    public String getLockType()
    {
        return lockType;
    }

    public void setLockType(String lockType)
    {
        this.lockType = lockType;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public Instant getCreatedAt()
    {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt)
    {
        this.createdAt = createdAt;
    }

    public Instant getClosedAt()
    {
        return closedAt;
    }

    public void setClosedAt(Instant closedAt)
    {
        this.closedAt = closedAt;
    }

    /** A locked vault keeps its money until the target date. */
    public boolean isLockedOn(LocalDate day)
    {
        return LOCKED.equals(lockType) && targetDate != null && day.isBefore(targetDate);
    }
}
