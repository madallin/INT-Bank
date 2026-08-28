package com.intbank.core.domain.vo;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Map;
import java.util.Objects;

public final class Money
{

    public static final int SCALE = 2;
    public static final RoundingMode ROUNDING = RoundingMode.HALF_EVEN;

    private final BigDecimal amount;
    private final String currency;

    private Money(BigDecimal amount, String currency)
    {
        if (amount == null || amount.signum() < 0)
        {
            throw new IllegalArgumentException("Money amount must be a non-negative number");
        }
        if (currency == null || currency.length() != 3 || !currency.equals(currency.toUpperCase()))
        {
            throw new IllegalArgumentException("Currency must be a 3-letter ISO code (e.g. RON, EUR)");
        }
        this.amount = amount.setScale(SCALE, ROUNDING);
        this.currency = currency;
    }

    public static Money of(double amount, String currency)
    {
        return of(BigDecimal.valueOf(amount), currency);
    }

    public static Money of(BigDecimal amount, String currency)
    {
        return new Money(amount, currency.toUpperCase());
    }

    public static Money zero(String currency)
    {
        return new Money(BigDecimal.ZERO, currency.toUpperCase());
    }

    public BigDecimal amount()
    {
        return amount;
    }

    public String currency()
    {
        return currency;
    }

    public Money add(Money other)
    {
        if (!this.currency.equals(other.currency))
        {
            throw new IllegalArgumentException("Currency mismatch: " + this.currency + " vs " + other.currency);
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }

    public Money subtract(Money other)
    {
        if (!this.currency.equals(other.currency))
        {
            throw new IllegalArgumentException("Currency mismatch: " + this.currency + " vs " + other.currency);
        }
        BigDecimal result = this.amount.subtract(other.amount);
        if (result.signum() < 0)
        {
            throw new IllegalArgumentException("Insufficient funds");
        }
        return new Money(result, this.currency);
    }

    public int compareTo(Money other)
    {
        if (!this.currency.equals(other.currency))
        {
            throw new IllegalArgumentException("Currency mismatch: " + this.currency + " vs " + other.currency);
        }
        return this.amount.compareTo(other.amount);
    }

    @Override
    public boolean equals(Object o)
    {
        if (this == o)
        {
            return true;
        }
        if (!(o instanceof Money other))
        {
            return false;
        }
        return currency.equals(other.currency) && amount.compareTo(other.amount) == 0;
    }

    @Override
    public int hashCode()
    {
        return Objects.hash(amount, currency);
    }

    @Override
    public String toString()
    {
        return String.format("%." + SCALE + "f %s", amount, currency);
    }

    public Map<String, Object> toJSON()
    {
        return Map.of("amount", amount, "currency", currency);
    }
}
