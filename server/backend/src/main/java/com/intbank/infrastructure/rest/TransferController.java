package com.intbank.infrastructure.rest;

import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.rest.dto.InitiateTransferRequest;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/transfers")
public class TransferController
{

    private static final Logger log = LoggerFactory.getLogger(TransferController.class);
    private final TransferUseCase transferUseCase;

    public TransferController(TransferUseCase transferUseCase)
    {
        this.transferUseCase = transferUseCase;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> initiate(
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
            @Valid @RequestBody InitiateTransferRequest body)
    {
        if (idempotencyKey == null || idempotencyKey.isBlank())
        {
            throw new IllegalArgumentException("Missing required Idempotency-Key header");
        }

        log.info("POST /transfers - {} -> {} | {} {}", body.getFromIban(), body.getToIban(), body.getAmount(), body.getCurrency());

        var result = transferUseCase.initiate(new TransferUseCase.InitiateTransferRequest(
            body.getFromIban(),
            body.getToIban(),
            BigDecimal.valueOf(body.getAmount()),
            body.getCurrency(),
            body.getReason(),
            body.getBeneficiaryName(),
            body.getSenderName(),
            idempotencyKey.trim()
        ));

        return Map.of(
                "status", HttpStatus.ACCEPTED.value(),
                "trackingId", result.trackingId(),
                "message", result.message(),
                "transferStatus", result.status().name()
        );
    }
}
