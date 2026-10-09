package com.intbank.core.domain.exception;

/**
 * A request that is well-formed but violates a banking rule. Carries a stable
 * machine-readable {@link #code()} so clients can show a localized message
 * instead of the server's prose.
 */
public class BusinessRuleException extends IllegalArgumentException
{

    public static final String CURRENCY_MISMATCH = "CURRENCY_MISMATCH";
    public static final String SAME_ACCOUNT = "SAME_ACCOUNT";
    public static final String INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS";
    public static final String ACCOUNT_NOT_OWNED = "ACCOUNT_NOT_OWNED";
    public static final String UNSUPPORTED_CURRENCY_PAIR = "UNSUPPORTED_CURRENCY_PAIR";
    public static final String INVALID_AMOUNT = "INVALID_AMOUNT";
    public static final String SCA_CHALLENGE_INVALID = "SCA_CHALLENGE_INVALID";
    public static final String SCA_PIN_INVALID = "SCA_PIN_INVALID";
    public static final String SCA_LOCKED = "SCA_LOCKED";
    public static final String DESTINATION_NOT_FOUND = "DESTINATION_NOT_FOUND";
    public static final String VAULT_NOT_FOUND = "VAULT_NOT_FOUND";
    public static final String VAULT_LOCKED = "VAULT_LOCKED";
    public static final String VAULT_INVALID = "VAULT_INVALID";
    public static final String QUOTE_EXPIRED = "QUOTE_EXPIRED";

    private final String code;
    private final java.util.Map<String, Object> details;

    public BusinessRuleException(String code, String message)
    {
        this(code, message, java.util.Map.of());
    }

    public BusinessRuleException(String code, String message, java.util.Map<String, Object> details)
    {
        super(message);
        this.code = code;
        this.details = java.util.Map.copyOf(details);
    }

    public String code()
    {
        return code;
    }

    /** Extra machine-readable fields for the client (e.g. {@code remainingAttempts}). */
    public java.util.Map<String, Object> details()
    {
        return details;
    }

    /** Response body: {@code success=false}, {@code code}, {@code error} and any details. */
    public java.util.Map<String, Object> toBody()
    {
        java.util.Map<String, Object> body = new java.util.LinkedHashMap<>(details);
        body.put("success", false);
        body.put("code", code);
        body.put("error", getMessage());
        return body;
    }
}
