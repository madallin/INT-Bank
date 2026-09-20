package com.intbank.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

/**
 * Tamper-evident, hash-chained audit ledger.
 *
 * <p>Each entry stores the SHA-256 digest of its payload plus a chain hash computed over a
 * deterministic concatenation of {@code previousHash}, {@code payloadDigest}, {@code sequenceId}
 * and the entry {@code timestamp}. Fields are joined with the ASCII pipe character {@code '|'},
 * which is used as an unambiguous separator and is deliberately excluded from all field values.
 * The canonical form hashed for an entry is:</p>
 *
 * <pre>
 * previousHash | payloadDigest | sequenceId | timestamp
 * </pre>
 *
 * <p>Because every entry commits to the actual hash of its predecessor, altering any stored
 * payload digest (for example, changing the amount of a posted transaction by one cent) forces
 * a hash mismatch, and altering linkage or ordering breaks the chain at a precisely reported
 * sequence id. All digests are rendered as lowercase hexadecimal strings of exactly 64
 * characters.</p>
 */
public class CryptographicAuditLedgerService
{
    private static final String CHAIN_FIELD_SEPARATOR = "|";
    private static final String GENESIS_PREVIOUS_HASH = "";
    private static final char[] HEX_DIGITS = "0123456789abcdef".toCharArray();

    private final Clock clock;

    public record LedgerHashEntry(
            long sequenceId,
            String entryHash,
            String previousHash,
            String payloadDigest,
            Instant timestamp)
    {
        public LedgerHashEntry
        {
            Objects.requireNonNull(entryHash, "entryHash must not be null");
            Objects.requireNonNull(previousHash, "previousHash must not be null");
            Objects.requireNonNull(payloadDigest, "payloadDigest must not be null");
            Objects.requireNonNull(timestamp, "timestamp must not be null");
        }
    }

    public record IntegrityCheckResult(
            boolean isValid,
            long brokenAtSequence,
            String expectedHash,
            String actualHash)
    {
    }

    /**
     * Creates a service backed by the system UTC clock.
     */
    public CryptographicAuditLedgerService()
    {
        this(Clock.systemUTC());
    }

    /**
     * Creates a service backed by the supplied clock, allowing deterministic tests to inject a
     * fixed time source.
     *
     * @param clock the clock used to timestamp appended entries, must not be null
     */
    public CryptographicAuditLedgerService(Clock clock)
    {
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    /**
     * Appends a new ledger entry. The timestamp is obtained from the configured clock, making the
     * result fully deterministic for a fixed clock and equal inputs. A null previous hash denotes
     * the genesis entry and is normalized to the empty string.
     *
     * @param sequenceId   the monotonic sequence id assigned to the entry
     * @param previousHash the actual entry hash of the predecessor, or null for the genesis entry
     * @param payloadData  the raw payload whose SHA-256 digest is committed, must not be null
     * @return the fully populated, hash-chained ledger entry
     */
    public LedgerHashEntry appendEntry(long sequenceId, String previousHash, String payloadData)
    {
        Objects.requireNonNull(payloadData, "payloadData must not be null");

        String normalizedPrevious = previousHash == null ? GENESIS_PREVIOUS_HASH : previousHash;
        String payloadDigest = sha256Hex(payloadData);
        Instant timestamp = clock.instant();
        String entryHash = computeEntryHash(normalizedPrevious, payloadDigest, sequenceId, timestamp);

        return new LedgerHashEntry(sequenceId, entryHash, normalizedPrevious, payloadDigest, timestamp);
    }

    /**
     * Verifies the integrity of a complete chain in order. The check detects the exact entry at
     * which integrity first fails by recomputing each entry hash from the payload digest,
     * sequence id, timestamp and the previous entry's actual hash, then comparing it to the stored
     * value. Broken linkage and non-sequential ids are reported as well.
     *
     * <p>A null list is rejected; an empty chain is considered valid.</p>
     *
     * @param chain the ordered chain to verify, must not be null
     * @return a result describing validity and, when broken, the offending sequence id plus the
     *         expected and actual values
     */
    public IntegrityCheckResult verifyChainIntegrity(List<LedgerHashEntry> chain)
    {
        Objects.requireNonNull(chain, "chain must not be null");

        if (chain.isEmpty())
        {
            return new IntegrityCheckResult(true, -1L, "", "");
        }

        LedgerHashEntry previous = null;
        for (LedgerHashEntry entry : chain)
        {
            Objects.requireNonNull(entry, "chain entry must not be null");

            if (previous != null)
            {
                long expectedSequence = previous.sequenceId() + 1L;
                if (entry.sequenceId() != expectedSequence)
                {
                    return new IntegrityCheckResult(
                            false,
                            entry.sequenceId(),
                            Long.toString(expectedSequence),
                            Long.toString(entry.sequenceId()));
                }

                if (!Objects.equals(entry.previousHash(), previous.entryHash()))
                {
                    return new IntegrityCheckResult(
                            false,
                            entry.sequenceId(),
                            previous.entryHash(),
                            entry.previousHash());
                }
            }

            String expectedHash = computeEntryHash(
                    entry.previousHash(),
                    entry.payloadDigest(),
                    entry.sequenceId(),
                    entry.timestamp());
            if (!expectedHash.equals(entry.entryHash()))
            {
                return new IntegrityCheckResult(
                        false,
                        entry.sequenceId(),
                        expectedHash,
                        entry.entryHash());
            }

            previous = entry;
        }

        return new IntegrityCheckResult(true, -1L, "", "");
    }

    private static String computeEntryHash(
            String previousHash,
            String payloadDigest,
            long sequenceId,
            Instant timestamp)
    {
        StringBuilder canonical = new StringBuilder();
        canonical.append(previousHash).append(CHAIN_FIELD_SEPARATOR)
                .append(payloadDigest).append(CHAIN_FIELD_SEPARATOR)
                .append(sequenceId).append(CHAIN_FIELD_SEPARATOR)
                .append(timestamp.toString());
        return sha256Hex(canonical.toString());
    }

    private static String sha256Hex(String input)
    {
        try
        {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(bytes.length * 2);
            for (byte value : bytes)
            {
                hex.append(HEX_DIGITS[(value >> 4) & 0x0F]);
                hex.append(HEX_DIGITS[value & 0x0F]);
            }
            return hex.toString();
        }
        catch (NoSuchAlgorithmException exception)
        {
            throw new IllegalStateException("SHA-256 algorithm is not available", exception);
        }
    }
}
