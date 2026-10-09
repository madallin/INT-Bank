package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.VaultJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface VaultJpaRepository extends JpaRepository<VaultJpaEntity, Long>
{
    List<VaultJpaEntity> findByUserIdAndStatusOrderByCreatedAtAsc(Long userId, String status);
}
