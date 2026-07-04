package com.intbank.service;

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
import java.util.Random;

@Service
public class BankingService
{

    private static final Logger log = LoggerFactory.getLogger(BankingService.class);
    private static final String BANK_CODE = "INTB";
    private static final int IBAN_ACCOUNT_LENGTH = 16;
    private static final String CARD_BIN = "499999";
    private static final int CARD_LENGTH = 16;
    private static final int DEFAULT_CARD_LIFETIME_YEARS = 3;
    private static final int MAX_RETRIES = 7;
    private static final Random RANDOM = new Random();

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
        String iban = generateIBAN(currency, countryCode);

        UserJpaEntity user = userRepo.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        AccountJpaEntity account = new AccountJpaEntity();
        account.setUser(user);
        account.setIBAN(iban);
        account.setMoneda(currency);
        account.setSold(BigDecimal.ZERO);
        account = accountRepo.save(account);

        Long accountId = account.getId();
        String cardNumber = CARD_BIN + generateRandomDigits(CARD_LENGTH - CARD_BIN.length());
        String cvv = generateRandomDigits(3);

        YearMonth expiry = YearMonth.now().plusYears(DEFAULT_CARD_LIFETIME_YEARS);
        String expiryMMYY = String.format("%02d/%02d", expiry.getMonthValue(), expiry.getYear() % 100);

        String encryptedCard = cryptoService.encryptAESGCM(cardNumber);
        String encryptedCVV = cryptoService.encryptAESGCM(cvv);
        String encryptedExpiry = cryptoService.encryptAESGCM(expiryMMYY);
        String token = "tok_" + generateRandomDigits(16);

        CardJpaEntity card = new CardJpaEntity();
        card.setUser(user);
        card.setAccount(account);
        card.setNumarCard(encryptedCard);
        card.setCvv(encryptedCVV);
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

    private String generateIBAN(String currency, String countryCode)
    {
        String country = countryCode.toUpperCase().substring(0, 2);
        String bban = BANK_CODE + generateRandomDigits(4) + (currency.equals("RON") ? "RON" : generateRandomDigits(3))
                + generateRandomDigits(IBAN_ACCOUNT_LENGTH - BANK_CODE.length() - 4 - 3);
        String checksum = computeIBANChecksum(bban);
        return country + checksum + bban;
    }

    private String computeIBANChecksum(String bban)
    {
        StringBuilder numeric = new StringBuilder();
        for (char c : (bban + "RO00").toCharArray())
        {
            if (c >= 'A' && c <= 'Z')
            {
                numeric.append(c - 'A' + 10);
            }
            else
            {
                numeric.append(c);
            }
        }
        java.math.BigInteger mod = new java.math.BigInteger(numeric.toString()).mod(java.math.BigInteger.valueOf(97));
        long checksum = 98 - mod.longValue();
        return String.format("%02d", checksum);
    }

    private String generateRandomDigits(int length)
    {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++)
        {
            sb.append(RANDOM.nextInt(10));
        }
        return sb.toString();
    }
}