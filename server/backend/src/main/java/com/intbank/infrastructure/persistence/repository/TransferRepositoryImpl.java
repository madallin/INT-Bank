package com.intbank.infrastructure.persistence.repository;

import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

@Repository
public class TransferRepositoryImpl implements TransferRepository
{

    private static final Logger log = LoggerFactory.getLogger(TransferRepositoryImpl.class);
    private final TransferJpaRepository jpaRepository;
    private final AccountJpaRepository accountJpaRepository;

    public TransferRepositoryImpl(TransferJpaRepository jpaRepository, AccountJpaRepository accountJpaRepository)
    {
        this.jpaRepository = jpaRepository;
        this.accountJpaRepository = accountJpaRepository;
    }

    @Override
    public Optional<TransferProjection> findById(String transferId)
    {
        return jpaRepository.findById(transferId).map(this::toProjection);
    }

    @Override
    @Transactional
    public void save(TransferProjection transfer)
    {
        TransferJpaEntity entity = jpaRepository.findById(transfer.id()).orElseGet(TransferJpaEntity::new);
        entity.setId(transfer.id());
        if (transfer.fromAccountId() != null)
        {
            entity.setFromAccount(accountJpaRepository.getReferenceById(Long.parseLong(transfer.fromAccountId())));
        }
        if (transfer.toAccountId() != null)
        {
            entity.setToAccount(accountJpaRepository.getReferenceById(Long.parseLong(transfer.toAccountId())));
        }
        entity.setAmount(transfer.amount() != null ? transfer.amount() : BigDecimal.ZERO);
        entity.setCurrency(transfer.currency());
        entity.setReason(transfer.reason());
        entity.setStatus(transfer.status().name());
        entity.setInitiatedAt(transfer.initiatedAt());
        entity.setCompletedAt(transfer.completedAt());
        entity.setFailureReason(transfer.failureReason());
        jpaRepository.save(entity);
        log.debug("Saved transfer: {}", transfer.id());
    }

    @Override
    @Transactional
    public void updateStatus(String transferId, TransferStatus status, Instant completedAt)
    {
        jpaRepository.updateStatus(transferId, status.name(), completedAt);
        log.debug("Updated transfer {} status to {}", transferId, status);
    }

    @Override
    @Transactional
    public void updateStatusWithEntity(String transferId, TransferStatus status, Instant completedAt, String failureReason)
    {
        TransferJpaEntity entity = jpaRepository.findById(transferId).orElse(null);
        if (entity != null)
        {
            entity.setStatus(status.name());
            entity.setFailureReason(failureReason);
            if (completedAt != null)
            {
                entity.setCompletedAt(completedAt);
            }
            jpaRepository.save(entity);
            log.debug("Updated transfer {} status to {} (with failureReason)", transferId, status);
        }
    }

    private TransferProjection toProjection(TransferJpaEntity entity)
    {
        return new TransferProjection(
                entity.getId(),
                entity.getFromAccountId(),
                entity.getToAccountId(),
                entity.getAmount() != null ? entity.getAmount() : BigDecimal.ZERO,
                entity.getCurrency(),
                entity.getReason(),
                TransferStatus.valueOf(entity.getStatus()),
                entity.getInitiatedAt(),
                entity.getCompletedAt(),
                entity.getFailureReason()
        );
    }
}