package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.DynamicChallengeJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DynamicChallengeJpaRepository extends JpaRepository<DynamicChallengeJpaEntity, String>
{
    Optional<DynamicChallengeJpaEntity> findByChallengeIdAndStatus(String challengeId, String status);
}
