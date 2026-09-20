package com.intbank.service;

import com.intbank.service.CryptographicAuditLedgerService.IntegrityCheckResult;
import com.intbank.service.CryptographicAuditLedgerService.LedgerHashEntry;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CryptographicAuditLedgerServiceTest
{
    private static final Instant FIXED_INSTANT = Instant.parse("2024-06-01T00:00:00Z");
    private static final Clock FIXED_CLOCK = Clock.fixed(FIXED_INSTANT, ZoneOffset.UTC);
    private static final String HEX_64 = "^[0-9a-f]{64}$";

    private final CryptographicAuditLedgerService service =
            new CryptographicAuditLedgerService(FIXED_CLOCK);

    private static String transactionPayload(String id, String amount)
    {
        return "transactionId=" + id + ";amount=" + amount;
    }

    private List<LedgerHashEntry> buildChain(int size)
    {
        List<LedgerHashEntry> chain = new ArrayList<>();
        String previousHash = null;
        for (int i = 1; i <= size; i++)
        {
            LedgerHashEntry entry = service.appendEntry(
                    i, previousHash, transactionPayload("T" + i, "100.00"));
            chain.add(entry);
            previousHash = entry.entryHash();
        }
        return chain;
    }

    @Test
    @DisplayName("Verifies a valid sequential chain")
    void verifiesValidSequentialChain()
    {
        List<LedgerHashEntry> chain = buildChain(4);

        IntegrityCheckResult result = service.verifyChainIntegrity(chain);

        assertTrue(result.isValid());
        assertEquals(-1L, result.brokenAtSequence());
        assertEquals("", result.expectedHash());
        assertEquals("", result.actualHash());
    }

    @Test
    @DisplayName("Treats empty chain as valid and genesis entry as hash-chained from empty string")
    void handlesEmptyChainAndGenesisEntry()
    {
        IntegrityCheckResult empty = service.verifyChainIntegrity(List.of());
        assertTrue(empty.isValid());
        assertEquals(-1L, empty.brokenAtSequence());
        assertEquals("", empty.expectedHash());
        assertEquals("", empty.actualHash());

        LedgerHashEntry genesis = service.appendEntry(1L, null, transactionPayload("T1", "100.00"));
        assertEquals("", genesis.previousHash());
        assertEquals(64, genesis.payloadDigest().length());
        assertEquals(64, genesis.entryHash().length());
        assertTrue(genesis.payloadDigest().matches(HEX_64));
        assertTrue(genesis.entryHash().matches(HEX_64));

        IntegrityCheckResult genesisResult = service.verifyChainIntegrity(List.of(genesis));
        assertTrue(genesisResult.isValid());
        assertEquals(-1L, genesisResult.brokenAtSequence());
    }

    @Test
    @DisplayName("Produces identical entries for equal inputs with the same fixed clock")
    void producesDeterministicEntries()
    {
        LedgerHashEntry first = service.appendEntry(7L, "abc", transactionPayload("T1", "250.50"));
        LedgerHashEntry second = service.appendEntry(7L, "abc", transactionPayload("T1", "250.50"));

        assertEquals(first, second);
        assertEquals(first.entryHash(), second.entryHash());
        assertEquals(first.payloadDigest(), second.payloadDigest());

        LedgerHashEntry differentAmount = service.appendEntry(
                7L, "abc", transactionPayload("T1", "250.51"));
        assertFalse(first.entryHash().equals(differentAmount.entryHash()));
    }

    @Test
    @DisplayName("Detects a one cent payload change and pinpoints the exact sequence id")
    void detectsOneCentPayloadTampering()
    {
        List<LedgerHashEntry> chain = buildChain(4);
        LedgerHashEntry original = chain.get(2);

        LedgerHashEntry modified = service.appendEntry(
                original.sequenceId(),
                original.previousHash(),
                transactionPayload("T3", new BigDecimal("100.00").add(new BigDecimal("0.01")).toPlainString()));

        LedgerHashEntry tampered = new LedgerHashEntry(
                original.sequenceId(),
                original.entryHash(),
                original.previousHash(),
                modified.payloadDigest(),
                original.timestamp());

        List<LedgerHashEntry> tamperedChain = new ArrayList<>(chain);
        tamperedChain.set(2, tampered);

        IntegrityCheckResult result = service.verifyChainIntegrity(tamperedChain);

        assertFalse(result.isValid());
        assertEquals(original.sequenceId(), result.brokenAtSequence());
        assertEquals(tampered.entryHash(), result.actualHash());
        assertFalse(result.expectedHash().equals(result.actualHash()));
        assertTrue(result.expectedHash().matches(HEX_64));
    }

    @Test
    @DisplayName("Detects a tampered stored entry hash")
    void detectsTamperedEntryHash()
    {
        List<LedgerHashEntry> chain = buildChain(3);
        LedgerHashEntry original = chain.get(1);
        LedgerHashEntry tampered = new LedgerHashEntry(
                original.sequenceId(),
                "0000000000000000000000000000000000000000000000000000000000000000",
                original.previousHash(),
                original.payloadDigest(),
                original.timestamp());

        List<LedgerHashEntry> tamperedChain = new ArrayList<>(chain);
        tamperedChain.set(1, tampered);

        IntegrityCheckResult result = service.verifyChainIntegrity(tamperedChain);

        assertFalse(result.isValid());
        assertEquals(original.sequenceId(), result.brokenAtSequence());
        assertEquals("0000000000000000000000000000000000000000000000000000000000000000",
                result.actualHash());
        assertFalse(result.expectedHash().equals(result.actualHash()));
    }

    @Test
    @DisplayName("Detects a removed entry as a non-sequential sequence id")
    void detectsRemovedEntry()
    {
        List<LedgerHashEntry> chain = buildChain(3);
        List<LedgerHashEntry> removed = new ArrayList<>(chain);
        removed.remove(1);

        IntegrityCheckResult result = service.verifyChainIntegrity(removed);

        assertFalse(result.isValid());
        assertEquals(3L, result.brokenAtSequence());
    }

    @Test
    @DisplayName("Detects a reordered entry through broken linkage or sequencing")
    void detectsReorderedEntry()
    {
        List<LedgerHashEntry> chain = buildChain(3);
        List<LedgerHashEntry> reordered = new ArrayList<>(chain);
        LedgerHashEntry second = reordered.remove(1);
        reordered.add(0, second);

        IntegrityCheckResult result = service.verifyChainIntegrity(reordered);

        assertFalse(result.isValid());
        assertTrue(result.brokenAtSequence() > 0L);
    }

    @Test
    @DisplayName("Rejects null arguments with clear exceptions")
    void rejectsNullArguments()
    {
        assertThrows(NullPointerException.class, () -> new CryptographicAuditLedgerService(null));
        assertThrows(NullPointerException.class, () -> service.appendEntry(1L, "abc", null));
        assertThrows(NullPointerException.class, () -> service.verifyChainIntegrity(null));

        NullPointerException payload = assertThrows(NullPointerException.class,
                () -> service.appendEntry(1L, null, null));
        assertNotNull(payload.getMessage());
    }
}
