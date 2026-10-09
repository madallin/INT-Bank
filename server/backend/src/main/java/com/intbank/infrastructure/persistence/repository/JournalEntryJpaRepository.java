package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface JournalEntryJpaRepository extends JpaRepository<JournalEntryJpaEntity, Long>
{

    /** One row per currency and entry type: {currency, type, sum of amounts, number of entries}. */
    @org.springframework.data.jpa.repository.Query(
            "SELECT j.currency, j.type, SUM(j.amount), COUNT(j) FROM JournalEntryJpaEntity j GROUP BY j.currency, j.type")
    java.util.List<Object[]> totalsByCurrencyAndType();
}
