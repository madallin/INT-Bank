package com.intbank.core.domain.vo;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class AccountNumbersTest
{

    @Test
    void issuedIbansAreStandardRomanianIntBankIbans()
    {
        for (String currency : new String[]{"RON", "EUR", "USD", "GBP"})
        {
            for (int i = 0; i < 200; i++)
            {
                String iban = AccountNumbers.newIban(currency);
                assertEquals(24, iban.length(), iban);
                assertTrue(iban.startsWith("RO"), iban);
                assertEquals("INTB", iban.substring(4, 8), iban);
                assertEquals(currency, iban.substring(8, 11), iban);
                assertTrue(AccountNumbers.isValidIban(iban), iban);
            }
        }
    }

    @Test
    void validatesKnownIbansAndCatchesTypos()
    {
        assertTrue(AccountNumbers.isValidIban("RO49AAAA1B31007593840000"));
        assertTrue(AccountNumbers.isValidIban("RO26 INTB RON0 0000 0000 0001"));
        assertTrue(AccountNumbers.isValidIban("DE89370400440532013000"));
        assertFalse(AccountNumbers.isValidIban("RO49AAAA1B31007593840001"), "one digit changed");
        assertFalse(AccountNumbers.isValidIban("RO49INTB0001EUR3F9A01BC"), "legacy 23-char number");
        assertFalse(AccountNumbers.isValidIban(null));
    }

    @Test
    void cardNumbersHaveTheBankBinAndAValidLuhnDigit()
    {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 500; i++)
        {
            String pan = AccountNumbers.newCardNumber();
            assertEquals(16, pan.length());
            assertTrue(pan.startsWith(AccountNumbers.CARD_BIN));
            assertTrue(AccountNumbers.isLuhnValid(pan), pan);
            seen.add(pan);
        }
        assertTrue(seen.size() > 490, "numbers should be random");
        assertTrue(AccountNumbers.isLuhnValid("4111111111111111"));
        assertFalse(AccountNumbers.isLuhnValid("4111111111111112"));
    }

    @Test
    void rejectsInvalidCurrencyCodes()
    {
        assertThrows(IllegalArgumentException.class, () -> AccountNumbers.newIban("ro"));
        assertThrows(IllegalArgumentException.class, () -> AccountNumbers.newIban(null));
    }
}
