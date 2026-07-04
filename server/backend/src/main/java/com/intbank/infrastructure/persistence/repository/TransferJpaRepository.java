package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;

@Repository
public interface TransferJpaRepository extends JpaRepository<TransferJpaEntity, String>
{

    @Modifying
    @Query("UPDATE TransferJpaEntity t SET t.status = :status, t.completedAt = :completedAt WHERE t.id = :id")
    void updateStatus(@Param("id") String id, @Param("status") String status, @Param("completedAt") Instant completedAt);

    @Modifying
    @Query("UPDATE TransferJpaEntity t SET t.status = :status, t.failureReason = :failureReason, t.completedAt = :completedAt WHERE t.id = :id")
    void updateStatusWithFailure(@Param("id") String id, @Param("status") String status,
                                  @Param("failureReason") String failureReason, @Param("completedAt") Instant completedAt);
}