package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CardJpaRepository extends JpaRepository<CardJpaEntity, Long>
{

    List<CardJpaEntity> findByUserId(Long userId);

    List<CardJpaEntity> findByAccountId(Long accountId);
}