package com.intbank.infrastructure.rest.dto;

import jakarta.validation.constraints.*;

public class InitiateTransferRequest
{

    @NotBlank
    private String fromIban;

    @NotBlank
    private String toIban;

    @DecimalMin("0.01")
    private double amount;

    @NotBlank
    private String currency;

    @NotBlank
    @Size(min = 3, max = 200)
    private String reason;

    @NotBlank
    private String beneficiaryName;

    @NotBlank
    private String senderName;

    public String getFromIban() { return fromIban; }

    public void setFromIban(String fromIban) { this.fromIban = fromIban; }

    public String getToIban() { return toIban; }

    public void setToIban(String toIban) { this.toIban = toIban; }

    public double getAmount() { return amount; }

    public void setAmount(double amount) { this.amount = amount; }

    public String getCurrency() { return currency; }

    public void setCurrency(String currency) { this.currency = currency; }

    public String getReason() { return reason; }

    public void setReason(String reason) { this.reason = reason; }

    public String getBeneficiaryName() { return beneficiaryName; }

    public void setBeneficiaryName(String beneficiaryName) { this.beneficiaryName = beneficiaryName; }

    public String getSenderName() { return senderName; }

    public void setSenderName(String senderName) { this.senderName = senderName; }
}