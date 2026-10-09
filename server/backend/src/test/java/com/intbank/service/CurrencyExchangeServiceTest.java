package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.transaction.PlatformTransactionManager;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Audit finding F2: the exchange must be owned, locked, ledgered and unable to mint money. */
class CurrencyExchangeServiceTest
{

    private static final long USER = 7L;

    private AccountJpaRepository accountRepo;
    private CurrencyService currencyService;
    private final Map<String, BigDecimal> ledgerNetByCurrency = new HashMap<>();
    private final Map<Long, AccountJpaEntity> accounts = new HashMap<>();
    private CurrencyExchangeService service;
    private final InMemoryExchangeQuoteStore quoteStore = new InMemoryExchangeQuoteStore();
    private java.time.Instant now = java.time.Instant.parse("2026-10-05T10:00:00Z");

    @BeforeEach
    void setUp()
    {
        accountRepo = mock(AccountJpaRepository.class);
        currencyService = mock(CurrencyService.class);
        LedgerRepository ledger = (transferId, accountId, type, amount, currency) ->
                ledgerNetByCurrency.merge(currency, "DEBIT".equals(type) ? amount : amount.negate(), BigDecimal::add);
        when(currencyService.getRate(anyString(), anyString()))
                .thenAnswer(i -> CurrencyService.staticRate(i.getArgument(0), i.getArgument(1)));
        when(accountRepo.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(accounts.get((Long) i.getArgument(0))));
        when(accountRepo.findByIdWithLock(anyLong())).thenAnswer(i -> Optional.ofNullable(accounts.get((Long) i.getArgument(0))));

        service = new CurrencyExchangeService(accountRepo, ledger, currencyService, mock(PlatformTransactionManager.class),
                quoteStore, new java.time.Clock() {
                    public java.time.ZoneId getZone() { return java.time.ZoneOffset.UTC; }
                    public java.time.Clock withZone(java.time.ZoneId zone) { return this; }
                    public java.time.Instant instant() { return now; }
                });

        account(1L, USER, "RON", "1000.00");
        account(2L, USER, "EUR", "100.00");
        account(3L, 99L, "EUR", "0.00");
        account(4L, USER, "RON", "0.00");
    }

    @Test
    void exchangeMovesBothBalancesAndBalancesTheLedgerPerCurrency()
    {
        var result = service.exchange(USER, 1L, 2L, new BigDecimal("100"));

        assertEquals(new BigDecimal("20.10"), result.destinationAmount());
        assertEquals(new BigDecimal("900.00"), accounts.get(1L).getSold());
        assertEquals(new BigDecimal("120.10"), accounts.get(2L).getSold());
        assertLedgerBalanced();
    }

    @Test
    void locksAccountsInAscendingIdOrder()
    {
        service.exchange(USER, 2L, 1L, new BigDecimal("10"));

        InOrder order = inOrder(accountRepo);
        order.verify(accountRepo).findByIdWithLock(1L);
        order.verify(accountRepo).findByIdWithLock(2L);
    }

    @Test
    void smallAmountsCannotBeRoundedUpIntoProfit()
    {
        // The old provider path rounded to whole units: 0.11 EUR -> 1 RON (about 9x the value).
        var result = service.exchange(USER, 2L, 1L, new BigDecimal("0.11"));

        assertEquals(new BigDecimal("0.54"), result.destinationAmount());
    }

    @Test
    void roundTripsNeverCreateMoney()
    {
        Random random = new Random(42);
        for (int i = 0; i < 500; i++)
        {
            BigDecimal amount = BigDecimal.valueOf(1 + random.nextInt(5_000), 2); // 0.01 .. 50.00 RON
            BigDecimal before = accounts.get(1L).getSold();
            try
            {
                var there = service.exchange(USER, 1L, 2L, amount);
                service.exchange(USER, 2L, 1L, there.destinationAmount());
            }
            catch (BusinessRuleException tooSmall)
            {
                assertEquals(BusinessRuleException.INVALID_AMOUNT, tooSmall.code());
            }
            assertTrue(accounts.get(1L).getSold().compareTo(before) <= 0,
                    "round trip of " + amount + " RON increased the balance");
        }
        assertLedgerBalanced();
    }

    @Test
    void roundTripsAtExactlyInverseRatesCannotGainFromRounding()
    {
        // With no spread, only rounding could create value (e.g. 0.02 RON -> 0.005 -> 0.01 EUR -> 0.04 RON).
        when(currencyService.getRate("RON", "EUR")).thenReturn(new BigDecimal("0.25"));
        when(currencyService.getRate("EUR", "RON")).thenReturn(new BigDecimal("4"));
        for (int cents = 1; cents <= 400; cents++)
        {
            BigDecimal amount = BigDecimal.valueOf(cents, 2);
            BigDecimal before = accounts.get(1L).getSold();
            try
            {
                var there = service.exchange(USER, 1L, 2L, amount);
                service.exchange(USER, 2L, 1L, there.destinationAmount());
            }
            catch (BusinessRuleException tooSmall)
            {
                assertEquals(BusinessRuleException.INVALID_AMOUNT, tooSmall.code());
            }
            assertTrue(accounts.get(1L).getSold().compareTo(before) <= 0,
                    "round trip of " + amount + " RON increased the balance");
        }
        assertLedgerBalanced();
    }

    @Test
    void rejectsAccountsTheCallerDoesNotOwn()
    {
        var error = assertThrows(BusinessRuleException.class, () -> service.exchange(USER, 1L, 3L, BigDecimal.TEN));
        assertEquals(BusinessRuleException.ACCOUNT_NOT_OWNED, error.code());
        assertEquals(new BigDecimal("1000.00"), accounts.get(1L).getSold());
    }

    @Test
    void rejectsInsufficientFundsWithoutTouchingBalances()
    {
        var error = assertThrows(BusinessRuleException.class, () -> service.exchange(USER, 2L, 1L, new BigDecimal("100.01")));
        assertEquals(BusinessRuleException.INSUFFICIENT_FUNDS, error.code());
        assertEquals(new BigDecimal("100.00"), accounts.get(2L).getSold());
        assertTrue(ledgerNetByCurrency.isEmpty());
    }

    @Test
    void rejectsSameAccountSameCurrencyAndBadAmounts()
    {
        assertEquals(BusinessRuleException.SAME_ACCOUNT,
                assertThrows(BusinessRuleException.class, () -> service.exchange(USER, 1L, 1L, BigDecimal.TEN)).code());
        assertEquals(BusinessRuleException.CURRENCY_MISMATCH,
                assertThrows(BusinessRuleException.class, () -> service.exchange(USER, 1L, 4L, BigDecimal.TEN)).code());
        for (String bad : new String[]{"0", "-5", "1.001"})
        {
            assertEquals(BusinessRuleException.INVALID_AMOUNT,
                    assertThrows(BusinessRuleException.class, () -> service.exchange(USER, 1L, 2L, new BigDecimal(bad))).code());
        }
    }

    @Test
    void aQuoteShowsTheExactOutcomeAndMovesNoMoney()
    {
        var quote = service.quote(USER, 1L, 2L, new BigDecimal("100"));

        assertEquals(new BigDecimal("20.10"), quote.destinationAmount());
        assertEquals("RON", quote.sourceCurrency());
        assertEquals(new BigDecimal("1000.00"), accounts.get(1L).getSold(), "quoting moves nothing");
        assertTrue(ledgerNetByCurrency.isEmpty());
    }

    @Test
    void retryingTheSameQuoteNeverExchangesTwice()
    {
        var quote = service.quote(USER, 1L, 2L, new BigDecimal("100"));

        var first = service.execute(USER, quote.quoteId());
        var retry = service.execute(USER, quote.quoteId());

        assertFalse(first.replayed());
        assertTrue(retry.replayed());
        assertEquals(first.result(), retry.result());
        assertEquals(new BigDecimal("900.00"), accounts.get(1L).getSold(), "debited once");
        assertEquals(new BigDecimal("120.10"), accounts.get(2L).getSold(), "credited once");
    }

    @Test
    void theQuotedRateIsHonouredEvenIfTheMarketMoves()
    {
        var quote = service.quote(USER, 1L, 2L, new BigDecimal("100"));
        when(currencyService.getRate("RON", "EUR")).thenReturn(new BigDecimal("0.300"));

        assertEquals(new BigDecimal("20.10"), service.execute(USER, quote.quoteId()).result().destinationAmount());
    }

    @Test
    void expiredOrSomeoneElsesQuotesAreRefused()
    {
        var quote = service.quote(USER, 1L, 2L, new BigDecimal("100"));

        assertEquals(BusinessRuleException.QUOTE_EXPIRED,
                assertThrows(BusinessRuleException.class, () -> service.execute(99L, quote.quoteId())).code());
        now = now.plus(CurrencyExchangeService.QUOTE_TTL);
        assertEquals(BusinessRuleException.QUOTE_EXPIRED,
                assertThrows(BusinessRuleException.class, () -> service.execute(USER, quote.quoteId())).code());
        assertEquals(new BigDecimal("1000.00"), accounts.get(1L).getSold());
    }

    @Test
    void aFailedExecutionCanBeRetriedWithTheSameQuote()
    {
        var quote = service.quote(USER, 2L, 1L, new BigDecimal("100"));
        accounts.get(2L).setSold(new BigDecimal("50.00")); // spent elsewhere after quoting

        assertEquals(BusinessRuleException.INSUFFICIENT_FUNDS,
                assertThrows(BusinessRuleException.class, () -> service.execute(USER, quote.quoteId())).code());

        accounts.get(2L).setSold(new BigDecimal("150.00")); // topped up
        assertFalse(service.execute(USER, quote.quoteId()).replayed());
        assertEquals(new BigDecimal("50.00"), accounts.get(2L).getSold());
    }

    @Test
    void unknownCurrencyPairsAreRejectedNotPricedAtPar()
    {
        var error = assertThrows(BusinessRuleException.class, () -> CurrencyService.staticRate("GBP", "USD"));
        assertEquals(BusinessRuleException.UNSUPPORTED_CURRENCY_PAIR, error.code());
    }

    private void assertLedgerBalanced()
    {
        ledgerNetByCurrency.forEach((currency, net) ->
                assertEquals(0, net.signum(), currency + " journal does not net to zero: " + net));
    }

    private void account(long id, long userId, String currency, String balance)
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(userId);
        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(id);
        account.setUser(user);
        account.setMoneda(currency);
        account.setSold(new BigDecimal(balance));
        accounts.put(id, account);
    }
}
