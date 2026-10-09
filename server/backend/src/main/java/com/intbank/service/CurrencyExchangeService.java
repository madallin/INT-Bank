package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Moves money between two accounts of the same customer held in different currencies.
 *
 * <p>Currencies and the rate are resolved first, outside any transaction, so a slow FX
 * provider never holds a row lock. Both rows are then locked (ascending id) and re-read in a
 * fresh transaction before the balance check, and the exchange is booked in the journal through the bank's FX position so that
 * every currency balances on its own:
 * <pre>
 *   DEBIT  customer source   (source ccy)   CREDIT fx position (source ccy)
 *   DEBIT  fx position       (dest ccy)     CREDIT customer destination (dest ccy)
 * </pre>
 * The destination amount is rounded down so rounding can never favour a round trip.
 */
@Service
public class CurrencyExchangeService
{

    private static final Logger log = LoggerFactory.getLogger(CurrencyExchangeService.class);

    /** Journal account id of the bank's internal FX position (not a customer account). */
    public static final long FX_POSITION_ACCOUNT_ID = 0L;

    private final AccountJpaRepository accountRepo;
    private final LedgerRepository ledgerRepository;
    private final CurrencyService currencyService;
    private final TransactionTemplate transactionTemplate;
    private final ExchangeQuoteStore quotes;
    private final java.time.Clock clock;

    /** How long a quoted rate is honoured. */
    public static final java.time.Duration QUOTE_TTL = java.time.Duration.ofSeconds(60);

    @org.springframework.beans.factory.annotation.Autowired
    public CurrencyExchangeService(AccountJpaRepository accountRepo,
                                   LedgerRepository ledgerRepository,
                                   CurrencyService currencyService,
                                   PlatformTransactionManager transactionManager,
                                   ExchangeQuoteStore quotes)
    {
        this(accountRepo, ledgerRepository, currencyService, transactionManager, quotes, java.time.Clock.systemUTC());
    }

    public CurrencyExchangeService(AccountJpaRepository accountRepo,
                                   LedgerRepository ledgerRepository,
                                   CurrencyService currencyService,
                                   PlatformTransactionManager transactionManager,
                                   ExchangeQuoteStore quotes,
                                   java.time.Clock clock)
    {
        this.accountRepo = accountRepo;
        this.ledgerRepository = ledgerRepository;
        this.currencyService = currencyService;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.quotes = quotes;
        this.clock = clock;
    }

    /** A rate offered to one customer for one exchange, valid until {@link #expiresAt}. */
    public record Quote(
            String quoteId,
            Long userId,
            Long fromAccountId,
            Long toAccountId,
            BigDecimal sourceAmount,
            String sourceCurrency,
            BigDecimal destinationAmount,
            String destinationCurrency,
            BigDecimal rate,
            java.time.Instant expiresAt
    )
    {
    }

    /** {@code replayed} is true when the quote had already been executed and this is the same outcome again. */
    public record Execution(ExchangeResult result, boolean replayed)
    {
    }

    public record ExchangeResult(
            String exchangeId,
            BigDecimal sourceAmount,
            String sourceCurrency,
            BigDecimal destinationAmount,
            String destinationCurrency,
            BigDecimal rate,
            BigDecimal fromAccountBalance,
            BigDecimal toAccountBalance
    )
    {
    }

    /** Quotes and executes in one go (the quote is never shown to anyone). */
    public ExchangeResult exchange(Long userId, Long fromAccountId, Long toAccountId, BigDecimal requestedAmount)
    {
        return execute(userId, quote(userId, fromAccountId, toAccountId, requestedAmount).quoteId()).result();
    }

    /**
     * Prices an exchange without moving money. The customer confirms these exact numbers;
     * {@link #execute} then books them, at this rate, at most once.
     */
    public Quote quote(Long userId, Long fromAccountId, Long toAccountId, BigDecimal requestedAmount)
    {
        if (requestedAmount == null || requestedAmount.signum() <= 0 || requestedAmount.scale() > 2)
        {
            throw new BusinessRuleException(BusinessRuleException.INVALID_AMOUNT,
                    "Suma trebuie să fie pozitivă, cu cel mult două zecimale");
        }
        if (fromAccountId.equals(toAccountId))
        {
            throw new BusinessRuleException(BusinessRuleException.SAME_ACCOUNT,
                    "Alege două conturi diferite pentru schimb");
        }
        BigDecimal sourceAmount = requestedAmount.setScale(2, RoundingMode.UNNECESSARY);

        // Not inside the locking transaction: an entity read here would be served stale from
        // the persistence context after the lock instead of re-read (relies on
        // spring.jpa.open-in-view=false, so this read and the transaction use separate contexts).
        AccountJpaEntity fromPeek = ownedAccount(userId, fromAccountId);
        AccountJpaEntity toPeek = ownedAccount(userId, toAccountId);
        String sourceCurrency = fromPeek.getMoneda();
        String destinationCurrency = toPeek.getMoneda();
        if (sourceCurrency.equals(destinationCurrency))
        {
            throw new BusinessRuleException(BusinessRuleException.CURRENCY_MISMATCH,
                    "Conturile au aceeași monedă; folosește un transfer");
        }
        BigDecimal rate = currencyService.getRate(sourceCurrency, destinationCurrency);
        BigDecimal destinationAmount = sourceAmount.multiply(rate).setScale(2, RoundingMode.DOWN);
        if (destinationAmount.signum() <= 0)
        {
            throw new BusinessRuleException(BusinessRuleException.INVALID_AMOUNT,
                    "Suma este prea mică pentru a fi schimbată");
        }

        Quote quote = new Quote("fxq-" + UUID.randomUUID(), userId, fromAccountId, toAccountId, sourceAmount,
                sourceCurrency, destinationAmount, destinationCurrency, rate, clock.instant().plus(QUOTE_TTL));
        quotes.save(quote, QUOTE_TTL);
        return quote;
    }

    /**
     * Books a quote. A quote moves money once: repeating the call (a network retry) returns the
     * original outcome instead of exchanging again.
     */
    public Execution execute(Long userId, String quoteId)
    {
        if (quoteId == null || quoteId.isBlank())
        {
            throw new BusinessRuleException(BusinessRuleException.QUOTE_EXPIRED, "Cere mai întâi o ofertă de curs.");
        }
        var done = quotes.result(quoteId);
        if (done.isPresent())
        {
            return new Execution(done.get(), true);
        }
        Quote quote = quotes.find(quoteId)
                .filter(q -> q.userId().equals(userId))
                .filter(q -> clock.instant().isBefore(q.expiresAt()))
                .orElseThrow(() -> new BusinessRuleException(BusinessRuleException.QUOTE_EXPIRED,
                        "Oferta de curs a expirat. Cere una nouă."));
        if (!quotes.claim(quoteId))
        {
            return quotes.result(quoteId).map(r -> new Execution(r, true))
                    .orElseThrow(() -> new IllegalStateException("This exchange is already being processed"));
        }
        try
        {
            ExchangeResult result = transactionTemplate.execute(status ->
                    book(userId, quote.fromAccountId(), quote.toAccountId(), quote.sourceAmount(), quote.sourceCurrency(),
                            quote.destinationCurrency(), quote.destinationAmount(), quote.rate()));
            quotes.saveResult(quoteId, result);
            return new Execution(result, false);
        }
        catch (RuntimeException e)
        {
            quotes.release(quoteId); // nothing was booked: the customer may try the same quote again
            throw e;
        }
    }

    private ExchangeResult book(Long userId, Long fromAccountId, Long toAccountId, BigDecimal sourceAmount,
                                String sourceCurrency, String destinationCurrency,
                                BigDecimal destinationAmount, BigDecimal rate)
    {
        // Lock in a global order to avoid deadlocks with concurrent transfers/exchanges.
        Long first = Math.min(fromAccountId, toAccountId);
        Long second = Math.max(fromAccountId, toAccountId);
        AccountJpaEntity lockedFirst = lockOwned(userId, first);
        AccountJpaEntity lockedSecond = lockOwned(userId, second);
        AccountJpaEntity from = first.equals(fromAccountId) ? lockedFirst : lockedSecond;
        AccountJpaEntity to = first.equals(fromAccountId) ? lockedSecond : lockedFirst;

        if (!from.getMoneda().equals(sourceCurrency) || !to.getMoneda().equals(destinationCurrency))
        {
            throw new IllegalStateException("Account currency changed during exchange");
        }
        if (from.getSold().compareTo(sourceAmount) < 0)
        {
            throw new BusinessRuleException(BusinessRuleException.INSUFFICIENT_FUNDS,
                    "Fonduri insuficiente în contul sursă");
        }

        from.setSold(from.getSold().subtract(sourceAmount));
        to.setSold(to.getSold().add(destinationAmount));
        accountRepo.save(from);
        accountRepo.save(to);

        String exchangeId = "FX-" + UUID.randomUUID();
        ledgerRepository.postEntry(exchangeId, from.getId(), "DEBIT", sourceAmount, sourceCurrency);
        ledgerRepository.postEntry(exchangeId, FX_POSITION_ACCOUNT_ID, "CREDIT", sourceAmount, sourceCurrency);
        ledgerRepository.postEntry(exchangeId, FX_POSITION_ACCOUNT_ID, "DEBIT", destinationAmount, destinationCurrency);
        ledgerRepository.postEntry(exchangeId, to.getId(), "CREDIT", destinationAmount, destinationCurrency);

        log.info("Exchange [{}] user {}: {} {} -> {} {} at {}", exchangeId, userId,
                sourceAmount, sourceCurrency, destinationAmount, destinationCurrency, rate);

        return new ExchangeResult(exchangeId, sourceAmount, sourceCurrency, destinationAmount, destinationCurrency,
                rate, from.getSold(), to.getSold());
    }

    private AccountJpaEntity ownedAccount(Long userId, Long accountId)
    {
        return accountRepo.findById(accountId)
                .filter(a -> a.getUserId() != null && a.getUserId().equals(userId) && a.isCurrent())
                .orElseThrow(() -> new BusinessRuleException(BusinessRuleException.ACCOUNT_NOT_OWNED,
                        "Unul sau ambele conturi nu au fost găsite"));
    }

    private AccountJpaEntity lockOwned(Long userId, Long accountId)
    {
        return accountRepo.findByIdWithLock(accountId)
                .filter(a -> a.getUserId() != null && a.getUserId().equals(userId) && a.isCurrent())
                .orElseThrow(() -> new BusinessRuleException(BusinessRuleException.ACCOUNT_NOT_OWNED,
                        "Unul sau ambele conturi nu au fost găsite"));
    }
}
