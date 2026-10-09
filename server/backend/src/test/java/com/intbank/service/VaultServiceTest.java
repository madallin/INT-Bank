package com.intbank.service;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.domain.vo.AccountNumbers;
import com.intbank.core.port.out.LedgerRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.entity.VaultJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.VaultJpaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.transaction.PlatformTransactionManager;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Savings vaults move real money between the customer's own accounts. */
class VaultServiceTest
{

    private static final long USER = 7L;
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 5);

    private final Map<Long, AccountJpaEntity> accounts = new HashMap<>();
    private final Map<Long, VaultJpaEntity> vaults = new HashMap<>();
    private final Map<String, BigDecimal> ledgerNet = new HashMap<>();
    private long nextId = 100;
    private AccountJpaRepository accountRepo;
    private VaultService service;
    private Clock clock = clockAt(TODAY);

    @BeforeEach
    void setUp()
    {
        accountRepo = mock(AccountJpaRepository.class);
        VaultJpaRepository vaultRepo = mock(VaultJpaRepository.class);
        when(accountRepo.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(accounts.get((Long) i.getArgument(0))));
        when(accountRepo.findByIdWithLock(anyLong())).thenAnswer(i -> Optional.ofNullable(accounts.get((Long) i.getArgument(0))));
        when(accountRepo.save(any())).thenAnswer(i -> {
            AccountJpaEntity a = i.getArgument(0);
            if (a.getId() == null) a.setId(nextId++);
            accounts.put(a.getId(), a);
            return a;
        });
        when(vaultRepo.save(any())).thenAnswer(i -> {
            VaultJpaEntity v = i.getArgument(0);
            if (v.getId() == null) v.setId(nextId++);
            vaults.put(v.getId(), v);
            return v;
        });
        when(vaultRepo.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(vaults.get((Long) i.getArgument(0))));
        when(vaultRepo.findByUserIdAndStatusOrderByCreatedAtAsc(anyLong(), anyString())).thenAnswer(i -> vaults.values().stream()
                .filter(v -> v.getUserId().equals(i.getArgument(0)) && v.getStatus().equals(i.getArgument(1))).toList());
        LedgerRepository ledger = (ref, accountId, type, amount, currency) ->
                ledgerNet.merge(currency, "DEBIT".equals(type) ? amount : amount.negate(), BigDecimal::add);

        service = new VaultService(vaultRepo, accountRepo, ledger, mock(PlatformTransactionManager.class), new DelegatingClock());

        account(1L, USER, "RON", "1000.00");
        account(2L, USER, "EUR", "200.00");
        account(3L, 99L, "RON", "500.00");
    }

    @Test
    void creatingAVaultOpensAnEmptyHiddenSavingsAccountInTheSourceCurrency()
    {
        var vault = service.create(USER, " Vacanță ", new BigDecimal("3000"), TODAY.plusMonths(6), "FLEXIBLE", 1L);

        AccountJpaEntity savings = accounts.get(vaults.get(vault.id()).getAccountId());
        assertEquals(AccountJpaEntity.TYPE_SAVINGS, savings.getType());
        assertFalse(savings.isCurrent());
        assertEquals("RON", savings.getMoneda());
        assertTrue(AccountNumbers.isValidIban(savings.getIBAN()));
        assertEquals("Vacanță", vault.name());
        assertEquals(0, BigDecimal.ZERO.compareTo(vault.balance()));
    }

    @Test
    void depositsAndWithdrawalsMoveRealMoneyAndBalanceTheLedger()
    {
        var vault = service.create(USER, "Laptop", new BigDecimal("5000"), null, "FLEXIBLE", 1L);

        assertEquals(new BigDecimal("400.00"), service.deposit(USER, vault.id(), 1L, new BigDecimal("400")).balance());
        assertEquals(new BigDecimal("600.00"), accounts.get(1L).getSold());

        assertEquals(new BigDecimal("150.00"), service.withdraw(USER, vault.id(), 1L, new BigDecimal("250")).balance());
        assertEquals(new BigDecimal("850.00"), accounts.get(1L).getSold());
        ledgerNet.forEach((currency, net) -> assertEquals(0, net.signum(), currency + " does not balance"));
    }

    @Test
    void locksBothAccountsInAscendingOrder()
    {
        var vault = service.create(USER, "Laptop", new BigDecimal("5000"), null, "FLEXIBLE", 1L);
        service.deposit(USER, vault.id(), 1L, BigDecimal.TEN);

        InOrder order = inOrder(accountRepo);
        order.verify(accountRepo).findByIdWithLock(1L);
        order.verify(accountRepo).findByIdWithLock(vaults.get(vault.id()).getAccountId());
    }

    @Test
    void aLockedVaultKeepsItsMoneyUntilTheTargetDate()
    {
        var vault = service.create(USER, "Avans casă", new BigDecimal("10000"), TODAY.plusDays(30), "LOCKED", 1L);
        service.deposit(USER, vault.id(), 1L, new BigDecimal("100"));
        assertTrue(service.list(USER).get(0).lockedToday());

        var locked = assertThrows(BusinessRuleException.class, () -> service.withdraw(USER, vault.id(), 1L, BigDecimal.ONE));
        assertEquals(BusinessRuleException.VAULT_LOCKED, locked.code());
        assertEquals(BusinessRuleException.VAULT_LOCKED,
                assertThrows(BusinessRuleException.class, () -> service.close(USER, vault.id(), 1L)).code());

        clock = clockAt(TODAY.plusDays(30));
        assertEquals(new BigDecimal("99.00"), service.withdraw(USER, vault.id(), 1L, BigDecimal.ONE).balance());
    }

    @Test
    void closingPaysOutTheRestAndTheVaultIsGone()
    {
        var vault = service.create(USER, "Cadouri", new BigDecimal("800"), null, "FLEXIBLE", 1L);
        service.deposit(USER, vault.id(), 1L, new BigDecimal("300"));

        service.close(USER, vault.id(), 1L);

        assertEquals(new BigDecimal("1000.00"), accounts.get(1L).getSold());
        assertTrue(service.list(USER).isEmpty());
        assertEquals(BusinessRuleException.VAULT_NOT_FOUND,
                assertThrows(BusinessRuleException.class, () -> service.deposit(USER, vault.id(), 1L, BigDecimal.ONE)).code());
    }

    @Test
    void refusesWhatWouldBreakTheRules()
    {
        var vault = service.create(USER, "Laptop", new BigDecimal("5000"), null, "FLEXIBLE", 1L);
        String savingsId = String.valueOf(vaults.get(vault.id()).getAccountId());

        assertCode(BusinessRuleException.INSUFFICIENT_FUNDS, () -> service.deposit(USER, vault.id(), 1L, new BigDecimal("1000.01")));
        assertCode(BusinessRuleException.CURRENCY_MISMATCH, () -> service.deposit(USER, vault.id(), 2L, BigDecimal.ONE));
        assertCode(BusinessRuleException.ACCOUNT_NOT_OWNED, () -> service.deposit(USER, vault.id(), 3L, BigDecimal.ONE));
        assertCode(BusinessRuleException.ACCOUNT_NOT_OWNED, () -> service.deposit(USER, vault.id(), Long.valueOf(savingsId), BigDecimal.ONE));
        assertCode(BusinessRuleException.VAULT_NOT_FOUND, () -> service.deposit(99L, vault.id(), 3L, BigDecimal.ONE));
        assertCode(BusinessRuleException.INVALID_AMOUNT, () -> service.deposit(USER, vault.id(), 1L, new BigDecimal("0.001")));
        assertCode(BusinessRuleException.INVALID_AMOUNT, () -> service.deposit(USER, vault.id(), 1L, new BigDecimal("-5")));
        assertEquals(new BigDecimal("1000.00"), accounts.get(1L).getSold(), "nothing moved");
        assertTrue(ledgerNet.isEmpty());
    }

    @Test
    void validatesNewVaults()
    {
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, " ", BigDecimal.TEN, null, "FLEXIBLE", 1L));
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, "x".repeat(61), BigDecimal.TEN, null, "FLEXIBLE", 1L));
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, "A", BigDecimal.TEN, null, "LOCKED", 1L));
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, "A", BigDecimal.TEN, TODAY, "FLEXIBLE", 1L));
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, "A", BigDecimal.TEN, null, "WEEKLY", 1L));
        assertCode(BusinessRuleException.INVALID_AMOUNT, () -> service.create(USER, "A", BigDecimal.ZERO, null, "FLEXIBLE", 1L));
        assertCode(BusinessRuleException.ACCOUNT_NOT_OWNED, () -> service.create(USER, "A", BigDecimal.TEN, null, "FLEXIBLE", 3L));
        assertCode(BusinessRuleException.ACCOUNT_NOT_OWNED, () -> service.create(USER, "A", BigDecimal.TEN, null, "FLEXIBLE", null));

        for (int i = 0; i < VaultService.MAX_ACTIVE_VAULTS; i++)
        {
            service.create(USER, "V" + i, BigDecimal.TEN, null, "FLEXIBLE", 1L);
        }
        assertCode(BusinessRuleException.VAULT_INVALID, () -> service.create(USER, "One too many", BigDecimal.TEN, null, "FLEXIBLE", 1L));
    }

    private static void assertCode(String code, org.junit.jupiter.api.function.Executable action)
    {
        assertEquals(code, assertThrows(BusinessRuleException.class, action).code());
    }

    private void account(long id, long userId, String currency, String balance)
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(userId);
        AccountJpaEntity a = new AccountJpaEntity();
        a.setId(id);
        a.setUser(user);
        a.setMoneda(currency);
        a.setSold(new BigDecimal(balance));
        a.setIBAN("RO00INTB" + id);
        accounts.put(id, a);
    }

    private static Clock clockAt(LocalDate day)
    {
        return Clock.fixed(day.atTime(12, 0).toInstant(ZoneOffset.UTC), ZoneOffset.UTC);
    }

    /** Lets a test move time forward after the service was built. */
    private final class DelegatingClock extends Clock
    {
        @Override
        public java.time.ZoneId getZone()
        {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone)
        {
            return this;
        }

        @Override
        public java.time.Instant instant()
        {
            return clock.instant();
        }
    }
}
