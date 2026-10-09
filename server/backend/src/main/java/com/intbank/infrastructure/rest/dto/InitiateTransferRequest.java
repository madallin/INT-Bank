package com.intbank.infrastructure.rest.dto;

import jakarta.validation.constraints.*;

public class InitiateTransferRequest
{

    @NotBlank
    private String fromIban;

    @NotBlank
    private String toIban;

    @DecimalMin("0.01")
    @jakarta.validation.constraints.NotNull
    @jakarta.validation.constraints.Digits(integer = 13, fraction = 2)
    private java.math.BigDecimal amount; // exact decimal; JSON numbers are parsed without binary rounding

    @NotBlank
    private String currency;

    @NotBlank
    @Size(min = 3, max = 200)
    private String reason;

    @NotBlank
    private String beneficiaryName;

    @NotBlank
    private String senderName;

    /** Step-up proof for payments at or above the SCA threshold (see StrongCustomerAuthService). */
    private String scaChallengeId;

    private String scaPin;

    public String getFromIban() { return fromIban; }

    public void setFromIban(String fromIban) { this.fromIban = fromIban; }

    public String getToIban() { return toIban; }

    public void setToIban(String toIban) { this.toIban = toIban; }

    public java.math.BigDecimal getAmount() { return amount; }

    public void setAmount(java.math.BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }

    public void setCurrency(String currency) { this.currency = currency; }

    public String getReason() { return reason; }

    public void setReason(String reason) { this.reason = reason; }

    public String getBeneficiaryName() { return beneficiaryName; }

    public void setBeneficiaryName(String beneficiaryName) { this.beneficiaryName = beneficiaryName; }

    public String getSenderName() { return senderName; }

    public String getScaChallengeId() { return scaChallengeId; }

    public void setScaChallengeId(String scaChallengeId) { this.scaChallengeId = scaChallengeId; }

    public String getScaPin() { return scaPin; }

    public void setScaPin(String scaPin) { this.scaPin = scaPin; }

    public void setSenderName(String senderName) { this.senderName = senderName; }
}