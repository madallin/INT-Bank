package com.intbank.core.port.out;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.function.Supplier;

public interface AccountRepository
{

    Optional<AccountProjection> findByIban(String iban);

    Optional<AccountProjection> findByIdWithLock(String accountId);

    void updateBalance(String accountId, BigDecimal newBalance);

    <T> T runInTransaction(Supplier<T> block);

    record AccountProjection(String id, Long userId, String iban, String moneda, BigDecimal sold)
    {
        public boolean hasSufficientFunds(BigDecimal amount)
        {
            return moneda != null && sold != null && sold.compareTo(amount) >= 0;
        }
    }
}