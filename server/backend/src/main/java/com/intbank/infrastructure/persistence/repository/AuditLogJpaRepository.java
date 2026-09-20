package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.AuditLogJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface AuditLogJpaRepository extends JpaRepository<AuditLogJpaEntity, Long>
{
    @Query(value = "SELECT * FROM audit_logs ORDER BY id DESC LIMIT 1", nativeQuery = true)
    Optional<AuditLogJpaEntity> findTopByOrderByIdDesc();

    List<AuditLogJpaEntity> findByUserIdOrderByIdDesc(Long userId);

    List<AuditLogJpaEntity> findAllByOrderByIdAsc();
}
