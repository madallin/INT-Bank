package com.intbank.infrastructure.persistence.repository;

import com.intbank.core.port.out.AccountRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.function.Supplier;

@Repository
public class AccountRepositoryImpl implements AccountRepository
{

    private static final Logger log = LoggerFactory.getLogger(AccountRepositoryImpl.class);

    private final AccountJpaRepository jpaRepository;

    public AccountRepositoryImpl(AccountJpaRepository jpaRepository)
    {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Optional<AccountProjection> findByIban(String iban)
    {
        return jpaRepository.findByIBAN(iban).map(this::toProjection);
    }

    @Override
    @Transactional
    public Optional<AccountProjection> findByIdWithLock(String accountId)
    {
        Long id = Long.parseLong(accountId);
        return jpaRepository.findByIdWithLock(id).map(this::toProjection);
    }

    @Override
    @Transactional
    public void updateBalance(String accountId, BigDecimal newBalance)
    {
        Long id = Long.parseLong(accountId);
        jpaRepository.updateBalance(id, newBalance.setScale(2, java.math.RoundingMode.HALF_EVEN));
        log.debug("Updated balance for account {}: {}", accountId, newBalance);
    }

    @Override
    @Transactional
    public <T> T runInTransaction(Supplier<T> block)
    {
        return block.get();
    }

    private AccountProjection toProjection(AccountJpaEntity entity)
    {
        return new AccountProjection(
                String.valueOf(entity.getId()),
                entity.getUserId(),
                entity.getIBAN(),
                entity.getMoneda(),
                entity.getSold() != null ? entity.getSold() : BigDecimal.ZERO
        );
    }
}