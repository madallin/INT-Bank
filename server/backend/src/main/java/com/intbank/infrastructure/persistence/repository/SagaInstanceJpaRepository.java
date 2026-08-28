package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.SagaInstanceJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SagaInstanceJpaRepository extends JpaRepository<SagaInstanceJpaEntity, String>
{
}
