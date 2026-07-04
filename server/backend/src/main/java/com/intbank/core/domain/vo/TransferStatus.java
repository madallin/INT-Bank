package com.intbank.core.domain.vo;

public enum TransferStatus
{
    PENDING,
    COMPLETED,
    FAILED;

    public static boolean isValidTransition(TransferStatus from, TransferStatus to)
    {
        if (from == PENDING)
        {
            return to == COMPLETED || to == FAILED;
        }
        return false;
    }

    public boolean isTerminal()
    {
        return this == COMPLETED || this == FAILED;
    }
}