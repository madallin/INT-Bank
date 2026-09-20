package com.intbank.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

public class StatementGenerationService
{
    private static final int MONEY_SCALE = 2;
    private static final RoundingMode MONEY_ROUNDING = RoundingMode.HALF_UP;
    private static final String DELIMITER = "|";
    private static final DateTimeFormatter COMPACT_DATE = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final char[] HEX_DIGITS = "0123456789abcdef".toCharArray();

    public record StatementRequest(String accountId, LocalDate startDate, LocalDate endDate, String currency)
    {
        public StatementRequest
        {
            if (accountId == null)
            {
                throw new NullPointerException("accountId must not be null");
            }
            if (accountId.isBlank())
            {
                throw new IllegalArgumentException("accountId must not be blank");
            }
            if (currency == null)
            {
                throw new NullPointerException("currency must not be null");
            }
            if (currency.isBlank())
            {
                throw new IllegalArgumentException("currency must not be blank");
            }
            Objects.requireNonNull(startDate, "startDate must not be null");
            Objects.requireNonNull(endDate, "endDate must not be null");
            if (startDate.isAfter(endDate))
            {
                throw new IllegalArgumentException("startDate must not be after endDate");
            }
        }
    }

    public record StatementMetadata(
            String statementNumber,
            BigDecimal openingBalance,
            BigDecimal closingBalance,
            BigDecimal totalDebits,
            BigDecimal totalCredits,
            String verificationHash)
    {
        public StatementMetadata
        {
            Objects.requireNonNull(statementNumber, "statementNumber must not be null");
            Objects.requireNonNull(openingBalance, "openingBalance must not be null");
            Objects.requireNonNull(closingBalance, "closingBalance must not be null");
            Objects.requireNonNull(totalDebits, "totalDebits must not be null");
            Objects.requireNonNull(totalCredits, "totalCredits must not be null");
            Objects.requireNonNull(verificationHash, "verificationHash must not be null");
        }
    }

    public record StatementTransaction(
            String id,
            LocalDate date,
            String description,
            BigDecimal amount,
            String type)
    {
        public StatementTransaction
        {
            if (id == null)
            {
                throw new NullPointerException("id must not be null");
            }
            if (id.isBlank())
            {
                throw new IllegalArgumentException("id must not be blank");
            }
            Objects.requireNonNull(date, "date must not be null");
            Objects.requireNonNull(amount, "amount must not be null");
            if (type == null)
            {
                throw new NullPointerException("type must not be null");
            }
            if (!"DEBIT".equalsIgnoreCase(type) && !"CREDIT".equalsIgnoreCase(type))
            {
                throw new IllegalArgumentException("type must be DEBIT or CREDIT");
            }
            type = type.toUpperCase(Locale.ROOT);
            amount = amount.setScale(MONEY_SCALE, MONEY_ROUNDING);
            description = description == null ? "" : description;
        }
    }

    public record GeneratedStatement(
            StatementRequest request,
            StatementMetadata metadata,
            List<StatementTransaction> transactions,
            Instant generatedAt)
    {
        public GeneratedStatement
        {
            Objects.requireNonNull(request, "request must not be null");
            Objects.requireNonNull(metadata, "metadata must not be null");
            Objects.requireNonNull(generatedAt, "generatedAt must not be null");
            transactions = transactions == null ? List.of() : List.copyOf(transactions);
        }
    }

    public GeneratedStatement generate(
            StatementRequest request,
            List<StatementTransaction> transactions,
            BigDecimal openingBalance,
            Instant generatedAt)
    {
        Objects.requireNonNull(request, "request must not be null");
        Objects.requireNonNull(openingBalance, "openingBalance must not be null");
        Objects.requireNonNull(generatedAt, "generatedAt must not be null");

        List<StatementTransaction> source = transactions == null ? List.of() : transactions;
        List<StatementTransaction> filtered = new ArrayList<>();
        for (StatementTransaction transaction : source)
        {
            if (transaction == null)
            {
                throw new NullPointerException("transaction must not be null");
            }
            LocalDate date = transaction.date();
            if (date.isBefore(request.startDate()) || date.isAfter(request.endDate()))
            {
                continue;
            }
            filtered.add(transaction);
        }
        filtered.sort(Comparator.comparing(StatementTransaction::date)
                .thenComparing(StatementTransaction::id));

        BigDecimal opening = money(openingBalance);
        BigDecimal totalDebits = money(BigDecimal.ZERO);
        BigDecimal totalCredits = money(BigDecimal.ZERO);
        BigDecimal runningBalance = opening;
        for (StatementTransaction transaction : filtered)
        {
            BigDecimal amount = money(transaction.amount());
            if (isDebit(transaction))
            {
                totalDebits = totalDebits.add(amount);
                runningBalance = runningBalance.subtract(amount);
            }
            else
            {
                totalCredits = totalCredits.add(amount);
                runningBalance = runningBalance.add(amount);
            }
        }
        totalDebits = money(totalDebits);
        totalCredits = money(totalCredits);
        BigDecimal closing = money(opening.add(totalCredits).subtract(totalDebits));

        if (runningBalance.compareTo(closing) != 0)
        {
            throw new IllegalStateException("running balance is inconsistent with closing balance");
        }

        String statementNumber = buildStatementNumber(request, filtered.size());
        String verificationHash = computeVerificationHash(
                request, filtered, opening, closing, totalDebits, totalCredits);
        StatementMetadata metadata = new StatementMetadata(
                statementNumber, opening, closing, totalDebits, totalCredits, verificationHash);

        return new GeneratedStatement(request, metadata, filtered, generatedAt);
    }

    public boolean verifyStatement(GeneratedStatement statement)
    {
        Objects.requireNonNull(statement, "statement must not be null");
        StatementRequest request = statement.request();
        StatementMetadata metadata = statement.metadata();
        List<StatementTransaction> transactions =
                statement.transactions() == null ? List.of() : statement.transactions();
        String recomputed = computeVerificationHash(
                request,
                transactions,
                metadata.openingBalance(),
                metadata.closingBalance(),
                metadata.totalDebits(),
                metadata.totalCredits());
        return recomputed.equals(metadata.verificationHash());
    }

    private String buildStatementNumber(StatementRequest request, int sequence)
    {
        StringBuilder canonical = new StringBuilder();
        appendField(canonical, request.accountId());
        appendField(canonical, request.startDate().format(COMPACT_DATE));
        appendField(canonical, request.endDate().format(COMPACT_DATE));
        appendField(canonical, Integer.toString(sequence));
        String digest = sha256Hex(canonical.toString());
        return "EXT-"
                + request.startDate().format(COMPACT_DATE)
                + "-"
                + request.endDate().format(COMPACT_DATE)
                + "-"
                + digest.substring(0, 12).toUpperCase(Locale.ROOT);
    }

    private String computeVerificationHash(
            StatementRequest request,
            List<StatementTransaction> transactions,
            BigDecimal opening,
            BigDecimal closing,
            BigDecimal totalDebits,
            BigDecimal totalCredits)
    {
        List<StatementTransaction> ordered = new ArrayList<>(transactions);
        ordered.sort(Comparator.comparing(StatementTransaction::date)
                .thenComparing(StatementTransaction::id));

        StringBuilder canonical = new StringBuilder();
        appendField(canonical, request.accountId());
        appendField(canonical, request.currency());
        appendField(canonical, request.startDate().toString());
        appendField(canonical, request.endDate().toString());
        appendField(canonical, opening.toPlainString());
        appendField(canonical, closing.toPlainString());
        appendField(canonical, totalDebits.toPlainString());
        appendField(canonical, totalCredits.toPlainString());
        appendField(canonical, Integer.toString(ordered.size()));
        for (StatementTransaction transaction : ordered)
        {
            appendField(canonical, transaction.id());
            appendField(canonical, transaction.date().toString());
            appendField(canonical, transaction.description());
            appendField(canonical, transaction.amount().toPlainString());
            appendField(canonical, transaction.type());
        }
        return sha256Hex(canonical.toString());
    }

    private static void appendField(StringBuilder builder, String value)
    {
        builder.append(value == null ? "" : value).append(DELIMITER);
    }

    private static boolean isDebit(StatementTransaction transaction)
    {
        return "DEBIT".equals(transaction.type());
    }

    private static BigDecimal money(BigDecimal value)
    {
        return value.setScale(MONEY_SCALE, MONEY_ROUNDING);
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
