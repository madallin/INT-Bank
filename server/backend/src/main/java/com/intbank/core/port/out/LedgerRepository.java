package com.intbank.core.port.out;

import java.math.BigDecimal;

public interface LedgerRepository
{

    void postEntry(String transferId, Long accountId, String entryType, BigDecimal amount, String currency);
}
