package com.intbank.service;

import com.intbank.core.domain.vo.AccountNumbers;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.CardJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.Map;

@Service
public class BankingService
{

    private static final Logger log = LoggerFactory.getLogger(BankingService.class);
    private static final int DEFAULT_CARD_LIFETIME_YEARS = 3;
    private static final int MAX_RETRIES = 7;

    private final AccountJpaRepository accountRepo;
    private final CardJpaRepository cardRepo;
    private final UserJpaRepository userRepo;
    private final CryptoService cryptoService;

    public BankingService(
        AccountJpaRepository accountRepo,
        CardJpaRepository cardRepo,
        UserJpaRepository userRepo,
        CryptoService cryptoService
    )
    {
        this.accountRepo = accountRepo;
        this.cardRepo = cardRepo;
        this.userRepo = userRepo;
        this.cryptoService = cryptoService;
    }

    @Transactional
    public Map<String, Object> createAccountAndCard(long userId, String currency, String countryCode)
    {
        String iban = AccountNumbers.newIban(currency.toUpperCase());

        UserJpaEntity user = userRepo.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        AccountJpaEntity account = new AccountJpaEntity();
        account.setUser(user);
        account.setIBAN(iban);
        account.setMoneda(currency);
        account.setSold(BigDecimal.ZERO);
        account = accountRepo.save(account);

        Long accountId = account.getId();
        String cardNumber = AccountNumbers.newCardNumber();
        // No CVV is generated or kept: card security codes must never be stored (PCI DSS v4.0 req. 3.3.1.2).

        YearMonth expiry = YearMonth.now().plusYears(DEFAULT_CARD_LIFETIME_YEARS);
        String expiryMMYY = String.format("%02d/%02d", expiry.getMonthValue(), expiry.getYear() % 100);

        String encryptedCard = cryptoService.encryptAESGCM(cardNumber);
        String encryptedExpiry = cryptoService.encryptAESGCM(expiryMMYY);
        String token = "tok_" + java.util.UUID.randomUUID().toString().replace("-", "");

        CardJpaEntity card = new CardJpaEntity();
        card.setUser(user);
        card.setAccount(account);
        card.setNumarCard(encryptedCard);
        card.setDataExpirare(encryptedExpiry);
        card.setDetinator(user.getNume() + " " + user.getPrenume());
        card.setToken(token);
        card = cardRepo.save(card);

        log.info("Account and card created: userId={}, accountId={}, IBAN={}, currency={}", userId, accountId, iban, currency);

        return Map.of(
                "account", Map.of("id", accountId, "IBAN", iban, "moneda", currency, "sold", 0),
                "card", Map.of("id", card.getId(), "token", token, "last4", cardNumber.substring(cardNumber.length() - 4),
                        "expiryMMYY", expiryMMYY, "accountId", accountId)
        );
    }

    public Map<String, Object> createAccountAndCardWithRetry(long userId, String currency, String countryCode)
    {
        for (int attempt = 1; attempt <= MAX_RETRIES; attempt++)
        {
            try
            {
                return createAccountAndCard(userId, currency, countryCode);
            }
            catch (Exception err)
            {
                if (err.getMessage() != null && err.getMessage().contains("unique") && attempt < MAX_RETRIES)
                {
                    log.warn("IBAN collision on attempt {}, retrying...", attempt);
                    continue;
                }
                log.error("createAccountAndCard failed", err);
                throw err;
            }
        }
        throw new RuntimeException("Failed to generate unique IBAN after " + MAX_RETRIES + " attempts");
    }
}