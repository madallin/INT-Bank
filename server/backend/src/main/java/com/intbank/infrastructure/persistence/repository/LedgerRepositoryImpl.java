package com.intbank.infrastructure.persistence.repository;

import com.intbank.core.port.out.LedgerRepository;
import com.intbank.infrastructure.persistence.entity.JournalEntryJpaEntity;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Repository
public class LedgerRepositoryImpl implements LedgerRepository
{

    private final JournalEntryJpaRepository journalRepo;

    public LedgerRepositoryImpl(JournalEntryJpaRepository journalRepo)
    {
        this.journalRepo = journalRepo;
    }

    @Override
    @Transactional
    public void postEntry(String transferId, Long accountId, String entryType, BigDecimal amount, String currency)
    {
        JournalEntryJpaEntity entry = new JournalEntryJpaEntity();
        entry.setTransferId(transferId);
        entry.setAccountId(accountId);
        entry.setType(JournalEntryJpaEntity.EntryType.valueOf(entryType));
        entry.setAmount(amount.setScale(2, java.math.RoundingMode.HALF_EVEN));
        entry.setCurrency(currency);
        journalRepo.save(entry);
    }
}
