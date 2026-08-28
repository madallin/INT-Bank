package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.SagaStepJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SagaStepJpaRepository extends JpaRepository<SagaStepJpaEntity, Long>
{

    List<SagaStepJpaEntity> findBySagaIdOrderByExecutedAtAsc(String sagaId);
}
