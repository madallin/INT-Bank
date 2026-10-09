package com.intbank.core.domain.vo;

import java.math.BigInteger;
import java.security.SecureRandom;

/**
 * Issues INTBank account and card numbers.
 *
 * <ul>
 *   <li>IBAN: Romanian format, 24 characters: {@code RO} + 2 check digits (ISO 7064 MOD 97-10)
 *       + bank code {@code INTB} + 16 characters (currency code + 13 random digits).</li>
 *   <li>Card number: 16 digits, {@link #CARD_BIN} prefix, Luhn check digit last.</li>
 * </ul>
 */
public final class AccountNumbers
{

    public static final String COUNTRY = "RO";
    public static final String BANK_CODE = "INTB";
    public static final int IBAN_LENGTH = 24;
    public static final String CARD_BIN = "499999";
    public static final int CARD_LENGTH = 16;

    private static final SecureRandom RANDOM = new SecureRandom();

    private AccountNumbers()
    {
    }

    /** A new, checksum-valid INTBank IBAN for an account held in {@code currency}. */
    public static String newIban(String currency)
    {
        if (currency == null || !currency.matches("[A-Z]{3}"))
        {
            throw new IllegalArgumentException("Currency must be a 3-letter ISO code: " + currency);
        }
        String bban = BANK_CODE + currency + randomDigits(IBAN_LENGTH - 4 - BANK_CODE.length() - 3);
        return COUNTRY + checkDigits(COUNTRY, bban) + bban;
    }

    /** ISO 13616 validity: allowed characters, Romanian length for RO, and MOD 97 == 1. */
    public static boolean isValidIban(String iban)
    {
        if (iban == null) return false;
        String c = iban.replaceAll("\\s+", "").toUpperCase();
        if (!c.matches("[A-Z]{2}\\d{2}[A-Z0-9]{11,30}")) return false;
        if (c.startsWith(COUNTRY) && c.length() != IBAN_LENGTH) return false;
        return mod97(c.substring(4) + c.substring(0, 4)) == 1;
    }

    /** A new 16-digit card number that passes the Luhn check. */
    public static String newCardNumber()
    {
        String body = CARD_BIN + randomDigits(CARD_LENGTH - CARD_BIN.length() - 1);
        return body + luhnCheckDigit(body);
    }

    public static boolean isLuhnValid(String number)
    {
        if (number == null || !number.matches("\\d{12,19}")) return false;
        String body = number.substring(0, number.length() - 1);
        return luhnCheckDigit(body) == number.charAt(number.length() - 1) - '0';
    }

    static String checkDigits(String country, String bban)
    {
        int check = 98 - mod97(bban + country + "00");
        return String.format("%02d", check);
    }

    private static int mod97(String alphanumeric)
    {
        StringBuilder numeric = new StringBuilder();
        for (char ch : alphanumeric.toCharArray())
        {
            numeric.append(Character.isLetter(ch) ? String.valueOf(ch - 'A' + 10) : String.valueOf(ch));
        }
        return new BigInteger(numeric.toString()).mod(BigInteger.valueOf(97)).intValue();
    }

    private static int luhnCheckDigit(String body)
    {
        int sum = 0;
        boolean doubleIt = true; // the digit next to the check digit is doubled
        for (int i = body.length() - 1; i >= 0; i--)
        {
            int d = body.charAt(i) - '0';
            if (doubleIt)
            {
                d *= 2;
                if (d > 9) d -= 9;
            }
            sum += d;
            doubleIt = !doubleIt;
        }
        return (10 - sum % 10) % 10;
    }

    private static String randomDigits(int length)
    {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++)
        {
            sb.append(RANDOM.nextInt(10));
        }
        return sb.toString();
    }
}
