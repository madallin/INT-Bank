package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.DynamicChallengeJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DynamicChallengeJpaRepository extends JpaRepository<DynamicChallengeJpaEntity, String>
{
    Optional<DynamicChallengeJpaEntity> findByChallengeIdAndStatus(String challengeId, String status);

    /** Atomically moves a challenge out of PENDING; returns 0 if someone else already did. */
    @Modifying
    @Query("UPDATE DynamicChallengeJpaEntity c SET c.status = :status WHERE c.challengeId = :id AND c.status = 'PENDING'")
    int transitionFromPending(@Param("id") String challengeId, @Param("status") String status);
}
