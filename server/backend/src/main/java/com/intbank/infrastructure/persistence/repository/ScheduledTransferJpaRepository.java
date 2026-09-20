package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ScheduledTransferJpaRepository extends JpaRepository<ScheduledTransferJpaEntity, Long>
{
    List<ScheduledTransferJpaEntity> findByUserIdOrderByNextRunDateAsc(Long userId);
    List<ScheduledTransferJpaEntity> findByStatusAndNextRunDateLessThanEqual(String status, LocalDate date);
}
