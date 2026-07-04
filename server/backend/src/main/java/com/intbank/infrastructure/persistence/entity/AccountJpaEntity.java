package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "accounts")
public class AccountJpaEntity
{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserJpaEntity user;

    @Column(nullable = false, unique = true, length = 34)
    private String IBAN;

    @Column(nullable = false, length = 3)
    private String moneda;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal sold = BigDecimal.ZERO;

    @Column(name = "created_at")
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @OneToMany(mappedBy = "account", fetch = FetchType.LAZY)
    private List<CardJpaEntity> cards = new ArrayList<>();

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

    public String getIBAN()
    {
        return IBAN;
    }

    public void setIBAN(String IBAN)
    {
        this.IBAN = IBAN;
    }

    public String getMoneda()
    {
        return moneda;
    }

    public void setMoneda(String moneda)
    {
        this.moneda = moneda;
    }

    public BigDecimal getSold()
    {
        return sold;
    }

    public void setSold(BigDecimal sold)
    {
        this.sold = sold;
    }

    public Instant getCreatedAt()
    {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt)
    {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt()
    {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt)
    {
        this.updatedAt = updatedAt;
    }

    public List<CardJpaEntity> getCards()
    {
        return cards;
    }

    public void setCards(List<CardJpaEntity> cards)
    {
        this.cards = cards;
    }

    @PrePersist
    protected void onCreate()
    {
        if (createdAt == null)
        {
            createdAt = Instant.now();
        }
        if (updatedAt == null)
        {
            updatedAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate()
    {
        updatedAt = Instant.now();
    }
}