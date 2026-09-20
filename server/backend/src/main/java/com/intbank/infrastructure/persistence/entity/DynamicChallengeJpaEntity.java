package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "dynamic_challenges")
public class DynamicChallengeJpaEntity
{

    @Id
    @Column(name = "challenge_id", length = 64)
    private String challengeId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(name = "to_iban", nullable = false, length = 34)
    private String toIban;

    @Column(nullable = false, length = 20)
    private String status = "PENDING";

    @Column(nullable = false, length = 128)
    private String signature;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    public String getChallengeId()
    {
        return challengeId;
    }

    public void setChallengeId(String challengeId)
    {
        this.challengeId = challengeId;
    }

    public Long getUserId()
    {
        return userId;
    }

    public void setUserId(Long userId)
    {
        this.userId = userId;
    }

    public BigDecimal getAmount()
    {
        return amount;
    }

    public void setAmount(BigDecimal amount)
    {
        this.amount = amount;
    }

    public String getToIban()
    {
        return toIban;
    }

    public void setToIban(String toIban)
    {
        this.toIban = toIban;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getSignature()
    {
        return signature;
    }

    public void setSignature(String signature)
    {
        this.signature = signature;
    }

    public Instant getCreatedAt()
    {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt)
    {
        this.createdAt = createdAt;
    }

    public Instant getExpiresAt()
    {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt)
    {
        this.expiresAt = expiresAt;
    }
}
