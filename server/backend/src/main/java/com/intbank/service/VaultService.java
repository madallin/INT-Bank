package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.domain.vo.AccountNumbers;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.VaultJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.VaultJpaRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Savings vaults. Each vault owns a SAVINGS account; deposits and withdrawals move real money
 * between it and one of the customer's current accounts (same currency), under row locks and
 * with a debit and a credit in the journal, exactly like a transfer between own accounts.
 */
@Service
public class VaultService
{

    public static final int MAX_ACTIVE_VAULTS = 10;
    public static final int MAX_NAME_LENGTH = 60;

    private final VaultJpaRepository vaultRepo;
    private final AccountJpaRepository accountRepo;
    private final LedgerRepository ledger;
    private final TransactionTemplate tx;
    private final Clock clock;

    @Autowired
    public VaultService(VaultJpaRepository vaultRepo, AccountJpaRepository accountRepo, LedgerRepository ledger,
                        PlatformTransactionManager transactionManager)
    {
        this(vaultRepo, accountRepo, ledger, transactionManager, Clock.systemDefaultZone());
    }

    public VaultService(VaultJpaRepository vaultRepo, AccountJpaRepository accountRepo, LedgerRepository ledger,
                        PlatformTransactionManager transactionManager, Clock clock)
    {
        this.vaultRepo = vaultRepo;
        this.accountRepo = accountRepo;
        this.ledger = ledger;
        this.tx = new TransactionTemplate(transactionManager);
        this.clock = clock;
    }

    /** A vault with its live balance, as the app shows it. */
    public record VaultView(Long id, String name, BigDecimal balance, BigDecimal targetAmount, String currency,
                            LocalDate targetDate, String lockType, boolean lockedToday, Instant createdAt)
    {
        public Map<String, Object> toMap()
        {
            var map = new java.util.LinkedHashMap<String, Object>();
            map.put("id", id);
            map.put("name", name);
            map.put("balance", balance);
            map.put("targetAmount", targetAmount);
            map.put("currency", currency);
            map.put("targetDate", targetDate != null ? targetDate.toString() : null);
            map.put("lockType", lockType);
            map.put("lockedToday", lockedToday);
            map.put("createdAt", createdAt != null ? createdAt.toString() : null);
            return map;
        }
    }

    public List<VaultView> list(Long userId)
    {
        return vaultRepo.findByUserIdAndStatusOrderByCreatedAtAsc(userId, VaultJpaEntity.ACTIVE).stream()
                .map(v -> view(v, accountRepo.findById(v.getAccountId()).orElseThrow()))
                .toList();
    }

    public VaultView create(Long userId, String name, BigDecimal targetAmount, LocalDate targetDate,
                            String lockType, Long sourceAccountId)
    {
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty() || cleanName.length() > MAX_NAME_LENGTH)
        {
            throw invalid("Numele seifului trebuie să aibă între 1 și " + MAX_NAME_LENGTH + " de caractere.");
        }
        BigDecimal target = money(targetAmount);
        String lock = lockType == null ? VaultJpaEntity.FLEXIBLE : lockType.toUpperCase();
        if (!lock.equals(VaultJpaEntity.FLEXIBLE) && !lock.equals(VaultJpaEntity.LOCKED))
        {
            throw invalid("Tipul seifului trebuie să fie FLEXIBLE sau LOCKED.");
        }
        LocalDate today = LocalDate.now(clock);
        if (targetDate != null && !targetDate.isAfter(today))
        {
            throw invalid("Data țintă trebuie să fie în viitor.");
        }
        if (lock.equals(VaultJpaEntity.LOCKED) && targetDate == null)
        {
            throw invalid("Un seif blocat are nevoie de o dată până la care rămâne blocat.");
        }
        if (vaultRepo.findByUserIdAndStatusOrderByCreatedAtAsc(userId, VaultJpaEntity.ACTIVE).size() >= MAX_ACTIVE_VAULTS)
        {
            throw invalid("Poți avea cel mult " + MAX_ACTIVE_VAULTS + " seifuri active.");
        }
        AccountJpaEntity source = ownedCurrent(userId, sourceAccountId,
                sourceAccountId == null ? null : accountRepo.findById(sourceAccountId).orElse(null));

        return tx.execute(status -> {
            AccountJpaEntity savings = new AccountJpaEntity();
            savings.setUser(source.getUser());
            savings.setIBAN(AccountNumbers.newIban(source.getMoneda()));
            savings.setMoneda(source.getMoneda());
            savings.setSold(BigDecimal.ZERO);
            savings.setType(AccountJpaEntity.TYPE_SAVINGS);
            savings.setCreatedAt(clock.instant());
            savings = accountRepo.save(savings);

            VaultJpaEntity vault = new VaultJpaEntity();
            vault.setUserId(userId);
            vault.setAccountId(savings.getId());
            vault.setName(cleanName);
            vault.setTargetAmount(target);
            vault.setTargetDate(targetDate);
            vault.setLockType(lock);
            vault.setCreatedAt(clock.instant());
            vault = vaultRepo.save(vault);
            return view(vault, savings);
        });
    }

    /** Moves money from one of the customer's current accounts into the vault. */
    public VaultView deposit(Long userId, Long vaultId, Long fromAccountId, BigDecimal amount)
    {
        BigDecimal value = money(amount);
        return tx.execute(status -> {
            VaultJpaEntity vault = activeVault(userId, vaultId);
            AccountJpaEntity[] locked = lockPair(fromAccountId, vault.getAccountId());
            AccountJpaEntity current = ownedCurrent(userId, fromAccountId, locked[0]);
            AccountJpaEntity savings = locked[1];
            move(current, savings, value, "VAULT-IN-");
            return view(vault, savings);
        });
    }

    /** Moves money from the vault back to one of the customer's current accounts. */
    public VaultView withdraw(Long userId, Long vaultId, Long toAccountId, BigDecimal amount)
    {
        BigDecimal value = money(amount);
        return tx.execute(status -> {
            VaultJpaEntity vault = activeVault(userId, vaultId);
            requireUnlocked(vault);
            AccountJpaEntity[] locked = lockPair(toAccountId, vault.getAccountId());
            AccountJpaEntity current = ownedCurrent(userId, toAccountId, locked[0]);
            AccountJpaEntity savings = locked[1];
            move(savings, current, value, "VAULT-OUT-");
            return view(vault, savings);
        });
    }

    /** Pays out whatever is left to a current account and closes the vault. */
    public void close(Long userId, Long vaultId, Long toAccountId)
    {
        tx.execute(status -> {
            VaultJpaEntity vault = activeVault(userId, vaultId);
            requireUnlocked(vault);
            AccountJpaEntity[] locked = lockPair(toAccountId, vault.getAccountId());
            AccountJpaEntity current = ownedCurrent(userId, toAccountId, locked[0]);
            AccountJpaEntity savings = locked[1];
            if (savings.getSold().signum() > 0)
            {
                move(savings, current, savings.getSold(), "VAULT-CLOSE-");
            }
            vault.setStatus(VaultJpaEntity.CLOSED);
            vault.setClosedAt(clock.instant());
            vaultRepo.save(vault);
            return null;
        });
    }

    private void move(AccountJpaEntity from, AccountJpaEntity to, BigDecimal amount, String referencePrefix)
    {
        if (!from.getMoneda().equals(to.getMoneda()))
        {
            throw new BusinessRuleException(BusinessRuleException.CURRENCY_MISMATCH,
                    "Seiful este în " + to.getMoneda() + "; alege un cont în aceeași monedă.");
        }
        if (from.getSold().compareTo(amount) < 0)
        {
            throw new BusinessRuleException(BusinessRuleException.INSUFFICIENT_FUNDS, "Fonduri insuficiente.");
        }
        from.setSold(from.getSold().subtract(amount));
        to.setSold(to.getSold().add(amount));
        accountRepo.save(from);
        accountRepo.save(to);
        String reference = referencePrefix + UUID.randomUUID();
        ledger.postEntry(reference, from.getId(), "DEBIT", amount, from.getMoneda());
        ledger.postEntry(reference, to.getId(), "CREDIT", amount, to.getMoneda());
    }

    /** Locks both rows in ascending id order (the order transfers and exchanges use). */
    private AccountJpaEntity[] lockPair(Long currentId, Long savingsId)
    {
        if (currentId == null || currentId.equals(savingsId))
        {
            throw new BusinessRuleException(BusinessRuleException.ACCOUNT_NOT_OWNED, "Alege unul dintre conturile tale curente.");
        }
        Long first = Math.min(currentId, savingsId);
        Long second = Math.max(currentId, savingsId);
        AccountJpaEntity a = accountRepo.findByIdWithLock(first).orElse(null);
        AccountJpaEntity b = accountRepo.findByIdWithLock(second).orElse(null);
        AccountJpaEntity current = first.equals(currentId) ? a : b;
        AccountJpaEntity savings = first.equals(currentId) ? b : a;
        if (savings == null)
        {
            throw new IllegalStateException("Vault account " + savingsId + " is missing");
        }
        return new AccountJpaEntity[]{current, savings};
    }

    private VaultJpaEntity activeVault(Long userId, Long vaultId)
    {
        return vaultRepo.findById(vaultId)
                .filter(v -> v.getUserId().equals(userId) && VaultJpaEntity.ACTIVE.equals(v.getStatus()))
                .orElseThrow(() -> new BusinessRuleException(BusinessRuleException.VAULT_NOT_FOUND, "Seiful nu există."));
    }

    private void requireUnlocked(VaultJpaEntity vault)
    {
        if (vault.isLockedOn(LocalDate.now(clock)))
        {
            throw new BusinessRuleException(BusinessRuleException.VAULT_LOCKED,
                    "Seiful este blocat până la " + vault.getTargetDate() + ".",
                    Map.of("lockedUntil", vault.getTargetDate().toString()));
        }
    }

    private static AccountJpaEntity ownedCurrent(Long userId, Long accountId, AccountJpaEntity account)
    {
        if (account == null || account.getUserId() == null || !account.getUserId().equals(userId) || !account.isCurrent())
        {
            throw new BusinessRuleException(BusinessRuleException.ACCOUNT_NOT_OWNED, "Alege unul dintre conturile tale curente.");
        }
        return account;
    }

    private static BigDecimal money(BigDecimal amount)
    {
        if (amount == null || amount.signum() <= 0 || amount.stripTrailingZeros().scale() > 2)
        {
            throw new BusinessRuleException(BusinessRuleException.INVALID_AMOUNT,
                    "Suma trebuie să fie pozitivă, cu cel mult două zecimale.");
        }
        return amount.setScale(2, RoundingMode.UNNECESSARY);
    }

    private static BusinessRuleException invalid(String message)
    {
        return new BusinessRuleException(BusinessRuleException.VAULT_INVALID, message);
    }

    private VaultView view(VaultJpaEntity vault, AccountJpaEntity savings)
    {
        return new VaultView(vault.getId(), vault.getName(), savings.getSold(), vault.getTargetAmount(),
                savings.getMoneda(), vault.getTargetDate(), vault.getLockType(),
                vault.isLockedOn(LocalDate.now(clock)), vault.getCreatedAt());
    }
}
