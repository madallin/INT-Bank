package com.intbank.core.port.in;

import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;

import java.math.BigDecimal;

public interface TransferUseCase
{

    InitiateTransferResponse initiate(InitiateTransferRequest request);

    TransferInitiatedEvent getLastPublishedEvent();

    record InitiateTransferRequest(
        String fromIban,
        String toIban,
        BigDecimal amount,
        String currency,
        String reason,
        String beneficiaryName,
        String senderName,
        String idempotencyKey
    )
    {
    }

    record InitiateTransferResponse(
        String trackingId,
        TransferStatus status,
        String message
    )
    {
    }
}