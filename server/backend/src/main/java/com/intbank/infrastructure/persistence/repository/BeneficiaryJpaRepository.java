package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.BeneficiaryJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BeneficiaryJpaRepository extends JpaRepository<BeneficiaryJpaEntity, Long>
{
    List<BeneficiaryJpaEntity> findByUserIdOrderByNameAsc(Long userId);
    Optional<BeneficiaryJpaEntity> findByUserIdAndIban(Long userId, String iban);
}
