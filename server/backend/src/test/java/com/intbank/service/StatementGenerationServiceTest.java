package com.intbank.service;

import com.intbank.service.StatementGenerationService.GeneratedStatement;
import com.intbank.service.StatementGenerationService.StatementMetadata;
import com.intbank.service.StatementGenerationService.StatementRequest;
import com.intbank.service.StatementGenerationService.StatementTransaction;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class StatementGenerationServiceTest
{
    private static final String ACCOUNT_ID = "RO49AAAA1B31007593840000";
    private static final String CURRENCY = "RON";
    private static final LocalDate START = LocalDate.of(2024, 1, 1);
    private static final LocalDate END = LocalDate.of(2024, 1, 31);
    private static final Instant GENERATED_AT = Instant.parse("2024-02-01T10:15:30Z");
    private static final BigDecimal OPENING = new BigDecimal("1000.00");

    private final StatementGenerationService service = new StatementGenerationService();

    private StatementRequest request()
    {
        return new StatementRequest(ACCOUNT_ID, START, END, CURRENCY);
    }

    private List<StatementTransaction> sampleTransactions()
    {
        return new ArrayList<>(List.of(
                new StatementTransaction("T1", LocalDate.of(2024, 1, 3), "Salary", new BigDecimal("250.50"), "CREDIT"),
                new StatementTransaction("T2", LocalDate.of(2024, 1, 5), "Rent", new BigDecimal("100.25"), "DEBIT"),
                new StatementTransaction("T3", LocalDate.of(2024, 1, 7), "Refund", new BigDecimal("49.50"), "credit"),
                new StatementTransaction("T4", LocalDate.of(2024, 1, 9), "Utilities", new BigDecimal("200.00"), "debit")
        ));
    }

    private GeneratedStatement generateSample()
    {
        return service.generate(request(), sampleTransactions(), OPENING, GENERATED_AT);
    }

    @Test
    @DisplayName("Computes exact scale-2 debit/credit totals and opening/closing balances")
    void computesBalancesAndTotals()
    {
        GeneratedStatement statement = generateSample();
        StatementMetadata metadata = statement.metadata();

        assertEquals(new BigDecimal("1000.00"), metadata.openingBalance());
        assertEquals(new BigDecimal("300.00"), metadata.totalCredits());
        assertEquals(new BigDecimal("300.25"), metadata.totalDebits());
        assertEquals(new BigDecimal("999.75"), metadata.closingBalance());
        assertEquals(2, metadata.openingBalance().scale());
        assertEquals(2, metadata.closingBalance().scale());
        assertEquals(2, metadata.totalDebits().scale());
        assertEquals(2, metadata.totalCredits().scale());
        assertEquals(4, statement.transactions().size());
        assertTrue(service.verifyStatement(statement));
    }

    @Test
    @DisplayName("Orders transactions deterministically by date then id")
    void ordersTransactionsByDateThenId()
    {
        StatementTransaction later = new StatementTransaction(
                "B", LocalDate.of(2024, 1, 20), "Later", new BigDecimal("5.00"), "CREDIT");
        StatementTransaction earlier = new StatementTransaction(
                "A", LocalDate.of(2024, 1, 10), "Earlier", new BigDecimal("5.00"), "CREDIT");

        GeneratedStatement statement = service.generate(
                request(), List.of(later, earlier), OPENING, GENERATED_AT);

        assertEquals("A", statement.transactions().get(0).id());
        assertEquals("B", statement.transactions().get(1).id());
    }

    @Test
    @DisplayName("Filters out transactions outside the inclusive date range")
    void filtersTransactionsOutsideDateRange()
    {
        List<StatementTransaction> transactions = List.of(
                new StatementTransaction("IN1", LocalDate.of(2024, 1, 10), "In range", new BigDecimal("10.00"), "CREDIT"),
                new StatementTransaction("IN2", START, "First day", new BigDecimal("1.00"), "DEBIT"),
                new StatementTransaction("IN3", END, "Last day", new BigDecimal("2.00"), "DEBIT"),
                new StatementTransaction("OUT1", LocalDate.of(2023, 12, 31), "Before", new BigDecimal("99.00"), "CREDIT"),
                new StatementTransaction("OUT2", LocalDate.of(2024, 2, 1), "After", new BigDecimal("77.00"), "CREDIT")
        );

        GeneratedStatement statement = service.generate(request(), transactions, OPENING, GENERATED_AT);

        assertEquals(3, statement.transactions().size());
        assertEquals(new BigDecimal("10.00"), statement.metadata().totalCredits());
        assertEquals(new BigDecimal("3.00"), statement.metadata().totalDebits());
        assertEquals(new BigDecimal("1007.00"), statement.metadata().closingBalance());
    }

    @Test
    @DisplayName("Handles an empty period without exceptions")
    void handlesEmptyPeriod()
    {
        GeneratedStatement statement = service.generate(request(), List.of(), OPENING, GENERATED_AT);

        assertTrue(statement.transactions().isEmpty());
        assertEquals(new BigDecimal("0.00"), statement.metadata().totalDebits());
        assertEquals(new BigDecimal("0.00"), statement.metadata().totalCredits());
        assertEquals(new BigDecimal("1000.00"), statement.metadata().openingBalance());
        assertEquals(statement.metadata().openingBalance(), statement.metadata().closingBalance());
        assertNotNull(statement.metadata().verificationHash());
        assertEquals(64, statement.metadata().verificationHash().length());
        assertTrue(service.verifyStatement(statement));
    }

    @Test
    @DisplayName("Produces a deterministic hash and statement number for equal inputs")
    void producesDeterministicHashAndStatementNumber()
    {
        GeneratedStatement first = generateSample();
        GeneratedStatement second = generateSample();

        assertEquals(first.metadata().verificationHash(), second.metadata().verificationHash());
        assertEquals(first.metadata().statementNumber(), second.metadata().statementNumber());
        assertTrue(service.verifyStatement(first));

        List<StatementTransaction> reversed = sampleTransactions();
        java.util.Collections.reverse(reversed);
        GeneratedStatement reordered = service.generate(request(), reversed, OPENING, GENERATED_AT);

        assertEquals(first.metadata().verificationHash(), reordered.metadata().verificationHash());
        assertEquals(first.metadata().statementNumber(), reordered.metadata().statementNumber());
    }

    @Test
    @DisplayName("Changes the hash when a transaction amount is tampered")
    void hashChangesWhenAmountTampered()
    {
        GeneratedStatement base = generateSample();
        List<StatementTransaction> tampered = sampleTransactions();
        StatementTransaction original = tampered.get(0);
        tampered.set(0, new StatementTransaction(
                original.id(), original.date(), original.description(),
                original.amount().add(new BigDecimal("0.01")), original.type()));

        GeneratedStatement modified = service.generate(request(), tampered, OPENING, GENERATED_AT);
        assertNotEquals(base.metadata().verificationHash(), modified.metadata().verificationHash());
    }

    @Test
    @DisplayName("Changes the hash when a transaction date is tampered")
    void hashChangesWhenDateTampered()
    {
        GeneratedStatement base = generateSample();
        List<StatementTransaction> tampered = sampleTransactions();
        StatementTransaction original = tampered.get(0);
        tampered.set(0, new StatementTransaction(
                original.id(), original.date().plusDays(1), original.description(),
                original.amount(), original.type()));

        GeneratedStatement modified = service.generate(request(), tampered, OPENING, GENERATED_AT);
        assertNotEquals(base.metadata().verificationHash(), modified.metadata().verificationHash());
    }

    @Test
    @DisplayName("Changes the hash when a transaction description is tampered")
    void hashChangesWhenDescriptionTampered()
    {
        GeneratedStatement base = generateSample();
        List<StatementTransaction> tampered = sampleTransactions();
        StatementTransaction original = tampered.get(1);
        tampered.set(1, new StatementTransaction(
                original.id(), original.date(), original.description() + " modified",
                original.amount(), original.type()));

        GeneratedStatement modified = service.generate(request(), tampered, OPENING, GENERATED_AT);
        assertNotEquals(base.metadata().verificationHash(), modified.metadata().verificationHash());
    }

    @Test
    @DisplayName("Changes the hash when the opening balance is tampered")
    void hashChangesWhenOpeningBalanceTampered()
    {
        GeneratedStatement base = generateSample();
        GeneratedStatement modified = service.generate(
                request(), sampleTransactions(), OPENING.add(new BigDecimal("1.00")), GENERATED_AT);

        assertNotEquals(base.metadata().verificationHash(), modified.metadata().verificationHash());
    }

    @Test
    @DisplayName("verifyStatement fails when the stored hash does not match the content")
    void verifyStatementFailsForTamperedContent()
    {
        GeneratedStatement base = generateSample();

        List<StatementTransaction> tamperedTransactions = sampleTransactions();
        StatementTransaction original = tamperedTransactions.get(0);
        tamperedTransactions.set(0, new StatementTransaction(
                original.id(), original.date(), original.description(),
                original.amount().add(new BigDecimal("5.00")), original.type()));
        GeneratedStatement tamperedList = new GeneratedStatement(
                base.request(), base.metadata(), tamperedTransactions, base.generatedAt());
        assertFalse(service.verifyStatement(tamperedList));

        StatementMetadata originalMetadata = base.metadata();
        StatementMetadata tamperedMetadata = new StatementMetadata(
                originalMetadata.statementNumber(),
                originalMetadata.openingBalance().add(new BigDecimal("1.00")),
                originalMetadata.closingBalance(),
                originalMetadata.totalDebits(),
                originalMetadata.totalCredits(),
                originalMetadata.verificationHash());
        GeneratedStatement tamperedOpening = new GeneratedStatement(
                base.request(), tamperedMetadata, base.transactions(), base.generatedAt());
        assertFalse(service.verifyStatement(tamperedOpening));
    }

    @Test
    @DisplayName("Accepts debit and credit type case-insensitively")
    void acceptsTypeCaseInsensitively()
    {
        GeneratedStatement statement = generateSample();
        assertEquals("CREDIT", statement.transactions().get(0).type());
        assertEquals("DEBIT", statement.transactions().get(1).type());
        assertThrows(IllegalArgumentException.class, () -> new StatementTransaction(
                "X", START, "Bad", new BigDecimal("1.00"), "TRANSFER"));
    }

    @Test
    @DisplayName("Rejects a request whose end date is before its start date")
    void rejectsInvertedDateRange()
    {
        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> new StatementRequest(ACCOUNT_ID, END, START, CURRENCY));
        assertNotNull(exception.getMessage());
        assertFalse(exception.getMessage().isBlank());
    }

    @Test
    @DisplayName("Rejects blank account id or currency")
    void rejectsBlankFields()
    {
        IllegalArgumentException blankAccount = assertThrows(IllegalArgumentException.class,
                () -> new StatementRequest("  ", START, END, CURRENCY));
        assertFalse(blankAccount.getMessage().isBlank());

        IllegalArgumentException blankCurrency = assertThrows(IllegalArgumentException.class,
                () -> new StatementRequest(ACCOUNT_ID, START, END, " "));
        assertFalse(blankCurrency.getMessage().isBlank());

        assertThrows(NullPointerException.class,
                () -> new StatementRequest(null, START, END, CURRENCY));
        assertThrows(NullPointerException.class,
                () -> new StatementRequest(ACCOUNT_ID, START, END, null));
    }

    @Test
    @DisplayName("Rejects null generation arguments")
    void rejectsNullGenerationArguments()
    {
        assertThrows(NullPointerException.class,
                () -> service.generate(null, List.of(), OPENING, GENERATED_AT));
        assertThrows(NullPointerException.class,
                () -> service.generate(request(), List.of(), null, GENERATED_AT));
        assertThrows(NullPointerException.class,
                () -> service.generate(request(), List.of(), OPENING, null));
        assertThrows(NullPointerException.class, () -> service.verifyStatement(null));
    }
}
