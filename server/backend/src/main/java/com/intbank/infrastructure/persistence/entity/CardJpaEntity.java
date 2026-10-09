package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "cards")
public class CardJpaEntity
{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserJpaEntity user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "account_id", nullable = false)
    private AccountJpaEntity account;

    @Column(name = "numar_card", nullable = false)
    private String numarCard;

    @Column(name = "data_expirare", nullable = false)
    private String dataExpirare;

    @Column(nullable = false)
    private String detinator;

    @Column(nullable = false, unique = true)
    private String token;

    @Column(name = "created_at")
    private Instant createdAt;

    /** ACTIVE or FROZEN. A frozen card must be declined for every authorization. */
    @Column(nullable = false, length = 16)
    private String status = STATUS_ACTIVE;

    @Column(name = "spending_limit", nullable = false, precision = 15, scale = 2)
    private java.math.BigDecimal spendingLimit = DEFAULT_SPENDING_LIMIT;

    @Column(name = "online_payments_enabled", nullable = false)
    private boolean onlinePaymentsEnabled = true;

    @Column(name = "contactless_enabled", nullable = false)
    private boolean contactlessEnabled = true;

    @Column(name = "status_changed_at")
    private Instant statusChangedAt;

    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_FROZEN = "FROZEN";
    public static final java.math.BigDecimal DEFAULT_SPENDING_LIMIT = new java.math.BigDecimal("5000.00");

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public UserJpaEntity getUser()
    {
        return user;
    }

    public void setUser(UserJpaEntity user)
    {
        this.user = user;
    }

    public Long getUserId()
    {
        return user != null ? user.getId() : null;
    }

    public AccountJpaEntity getAccount()
    {
        return account;
    }

    public void setAccount(AccountJpaEntity account)
    {
        this.account = account;
    }

    public Long getAccountId()
    {
        return account != null ? account.getId() : null;
    }

    public String getNumarCard()
    {
        return numarCard;
    }

    public void setNumarCard(String numarCard)
    {
        this.numarCard = numarCard;
    }

    public String getDataExpirare()
    {
        return dataExpirare;
    }

    public void setDataExpirare(String dataExpirare)
    {
        this.dataExpirare = dataExpirare;
    }

    public String getDetinator()
    {
        return detinator;
    }

    public void setDetinator(String detinator)
    {
        this.detinator = detinator;
    }

    public String getToken()
    {
        return token;
    }

    public void setToken(String token)
    {
        this.token = token;
    }

    public Instant getCreatedAt()
    {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt)
    {
        this.createdAt = createdAt;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public boolean isFrozen()
    {
        return STATUS_FROZEN.equals(status);
    }

    public java.math.BigDecimal getSpendingLimit()
    {
        return spendingLimit;
    }

    public void setSpendingLimit(java.math.BigDecimal spendingLimit)
    {
        this.spendingLimit = spendingLimit;
    }

    public boolean isOnlinePaymentsEnabled()
    {
        return onlinePaymentsEnabled;
    }

    public void setOnlinePaymentsEnabled(boolean onlinePaymentsEnabled)
    {
        this.onlinePaymentsEnabled = onlinePaymentsEnabled;
    }

    public boolean isContactlessEnabled()
    {
        return contactlessEnabled;
    }

    public void setContactlessEnabled(boolean contactlessEnabled)
    {
        this.contactlessEnabled = contactlessEnabled;
    }

    public Instant getStatusChangedAt()
    {
        return statusChangedAt;
    }

    public void setStatusChangedAt(Instant statusChangedAt)
    {
        this.statusChangedAt = statusChangedAt;
    }

    @PrePersist
    protected void onCreate()
    {
        if (createdAt == null)
        {
            createdAt = Instant.now();
        }
    }
}