package com.intbank;

import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** What JournalEntryJpaRepository.totalsByCurrencyAndType returns for the given entries. */
public final class LedgerRows
{
    private LedgerRows()
    {
    }

    public static List<Object[]> of(JournalEntryJpaEntity... entries)
    {
        Map<String, Object[]> rows = new LinkedHashMap<>();
        for (JournalEntryJpaEntity e : entries)
        {
            Object[] row = rows.computeIfAbsent(e.getCurrency() + "|" + e.getType(),
                    k -> new Object[]{e.getCurrency(), e.getType(), BigDecimal.ZERO, 0L});
            row[2] = ((BigDecimal) row[2]).add(e.getAmount());
            row[3] = (Long) row[3] + 1;
        }
        return new ArrayList<>(rows.values());
    }
}
