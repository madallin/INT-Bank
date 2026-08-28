package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface JournalEntryJpaRepository extends JpaRepository<JournalEntryJpaEntity, Long>
{
}
