package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.Optional;

@Repository
public interface AccountJpaRepository extends JpaRepository<AccountJpaEntity, Long>
{

    Optional<AccountJpaEntity> findByIBAN(String iban);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM AccountJpaEntity a WHERE a.id = :id")
    Optional<AccountJpaEntity> findByIdWithLock(@Param("id") Long id);

    @Modifying
    @Query("UPDATE AccountJpaEntity a SET a.sold = :balance, a.updatedAt = CURRENT_TIMESTAMP WHERE a.id = :id")
    void updateBalance(@Param("id") Long id, @Param("balance") BigDecimal balance);
}