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

    @Column(nullable = false)
    private String cvv;

    @Column(name = "data_expirare", nullable = false)
    private String dataExpirare;

    @Column(nullable = false)
    private String detinator;

    @Column(nullable = false, unique = true)
    private String token;

    @Column(name = "created_at")
    private Instant createdAt;

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

    public String getCvv()
    {
        return cvv;
    }

    public void setCvv(String cvv)
    {
        this.cvv = cvv;
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

    @PrePersist
    protected void onCreate()
    {
        if (createdAt == null)
        {
            createdAt = Instant.now();
        }
    }
}