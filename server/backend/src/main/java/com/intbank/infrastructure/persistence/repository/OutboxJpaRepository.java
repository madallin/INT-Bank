package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OutboxJpaRepository extends JpaRepository<OutboxJpaEntity, Long>
{

    List<OutboxJpaEntity> findByStatusOrderByCreatedAtAsc(String status);

    @Query("SELECT COUNT(o) FROM OutboxJpaEntity o WHERE o.status = :status")
    long countByStatus(String status);

    List<OutboxJpaEntity> findTop100ByStatusAndRetryCountLessThanOrderByCreatedAtAsc(String status, int maxRetries);

    long countByStatusAndRetryCountGreaterThanEqual(String status, int maxRetries);
}