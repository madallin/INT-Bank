package com.intbank.core.domain.vo;

import java.util.Objects;

public final class Money
{

    private final double amount;
    private final String currency;

    private Money(double amount, String currency)
    {
        if (!Double.isFinite(amount) || amount < 0)
        {
            throw new IllegalArgumentException("Money amount must be a finite non-negative number");
        }
        if (currency.length() != 3 || !currency.equals(currency.toUpperCase()))
        {
            throw new IllegalArgumentException("Currency must be a 3-letter ISO code (e.g. RON, EUR)");
        }
        this.amount = Math.round(amount * 100.0) / 100.0;
        this.currency = currency;
    }

    public static Money of(double amount, String currency)
    {
        return new Money(amount, currency.toUpperCase());
    }

    public static Money zero(String currency)
    {
        return new Money(0, currency.toUpperCase());
    }

    public double amount()
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
        return Money.of(this.amount + other.amount, this.currency);
    }

    public Money subtract(Money other)
    {
        if (!this.currency.equals(other.currency))
        {
            throw new IllegalArgumentException("Currency mismatch: " + this.currency + " vs " + other.currency);
        }
        double result = this.amount - other.amount;
        if (result < 0)
        {
            throw new IllegalArgumentException("Insufficient funds");
        }
        return Money.of(result, this.currency);
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
        return Double.compare(other.amount, amount) == 0 && currency.equals(other.currency);
    }

    @Override
    public int hashCode()
    {
        return Objects.hash(amount, currency);
    }

    @Override
    public String toString()
    {
        return String.format("%.2f %s", amount, currency);
    }

    public java.util.Map<String, Object> toJSON()
    {
        return java.util.Map.of("amount", amount, "currency", currency);
    }
}