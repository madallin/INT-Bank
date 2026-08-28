package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.ProcessedEventJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ProcessedEventJpaRepository extends JpaRepository<ProcessedEventJpaEntity, String>
{

    Optional<ProcessedEventJpaEntity> findByEventKey(String eventKey);
}
