package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.IdempotencyRecordJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface IdempotencyJpaRepository extends JpaRepository<IdempotencyRecordJpaEntity, String>
{

    Optional<IdempotencyRecordJpaEntity> findByIdempotencyKey(String key);
}
