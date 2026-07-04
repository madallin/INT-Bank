package com.intbank.core.domain.entity;

import com.intbank.core.domain.vo.Money;

import java.util.Objects;

public class Account
{

    private final String id;
    private final Long userId;
    private final String iban;
    private Money balance;

    public Account(String id, Long userId, String iban, Money balance)
    {
        this.id = id;
        this.userId = userId;
        this.iban = iban;
        this.balance = balance;
    }

    public String id()
    {
        return id;
    }

    public Long userId()
    {
        return userId;
    }

    public String iban()
    {
        return iban;
    }

    public Money balance()
    {
        return balance;
    }

    public void credit(Money amount)
    {
        this.balance = this.balance.add(amount);
    }

    public void debit(Money amount)
    {
        this.balance = this.balance.subtract(amount);
    }

    public boolean hasSufficientFunds(double amount, String currency)
    {
        return balance.amount() >= amount && balance.currency().equals(currency);
    }

    @Override
    public boolean equals(Object o)
    {
        if (this == o)
        {
            return true;
        }
        if (!(o instanceof Account account))
        {
            return false;
        }
        return Objects.equals(id, account.id);
    }

    @Override
    public int hashCode()
    {
        return Objects.hash(id);
    }

    @Override
    public String toString()
    {
        return "Account[id=" + id + ", iban=" + iban + ", balance=" + balance + "]";
    }
}