package com.intbank.core.domain.vo;

import java.util.Objects;
import java.util.regex.Pattern;

public final class Iban
{

    private static final Pattern IBAN_REGEX = Pattern.compile("^[A-Z]{2}\\d{2}[A-Z0-9]{4,30}$");

    private final String value;
    private final String countryCode;

    public Iban(String value)
    {
        String normalized = value.replaceAll("\\s+", "").toUpperCase();
        if (!IBAN_REGEX.matcher(normalized).matches())
        {
            throw new IllegalArgumentException("Invalid IBAN format: " + value);
        }
        this.value = normalized;
        this.countryCode = normalized.substring(0, 2);
    }

    public static Iban of(String value)
    {
        return new Iban(value);
    }

    public String value()
    {
        return value;
    }

    public String countryCode()
    {
        return countryCode;
    }

    public String formatted()
    {
        return value.replaceAll("(.{4})", "$1 ").trim();
    }

    public String masked()
    {
        return value.substring(0, 4) + " **** " + value.substring(value.length() - 4);
    }

    @Override
    public String toString()
    {
        return value;
    }

    @Override
    public boolean equals(Object o)
    {
        if (this == o)
        {
            return true;
        }
        if (!(o instanceof Iban other))
        {
            return false;
        }
        return value.equals(other.value);
    }

    @Override
    public int hashCode()
    {
        return Objects.hash(value);
    }
}