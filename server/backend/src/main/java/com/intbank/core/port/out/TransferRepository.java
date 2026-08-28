package com.intbank.core.port.out;

import com.intbank.core.domain.vo.TransferStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

public interface TransferRepository
{

    Optional<TransferProjection> findById(String transferId);

    void save(TransferProjection transfer);

    void updateStatus(String transferId, TransferStatus status, Instant completedAt);

    void updateStatusWithEntity(String transferId, TransferStatus status, Instant completedAt, String failureReason);

    record TransferProjection(String id, String fromAccountId, String toAccountId, BigDecimal amount, String currency,
                             String reason, TransferStatus status, Instant initiatedAt, Instant completedAt,
                             String failureReason)
    {
    }
}