package com.intbank.core.port.in;

import com.intbank.core.domain.event.TransferInitiatedEvent;
import com.intbank.core.domain.vo.TransferStatus;

public interface TransferUseCase
{

    InitiateTransferResponse initiate(InitiateTransferRequest request);

    TransferInitiatedEvent getLastPublishedEvent();

    record InitiateTransferRequest(
        String fromIban,
        String toIban,
        double amount,
        String currency,
        String reason,
        String beneficiaryName,
        String senderName
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