package com.intbank;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.StatementService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class StatementServiceTest
{

    @Mock
    private AccountJpaRepository accountRepo;

    @Mock
    private TransferJpaRepository transferRepo;

    @Mock
    private AuditLogService auditLogService;

    private StatementService statementService;

    @BeforeEach
    void setUp()
    {
        statementService = new StatementService(accountRepo, transferRepo, auditLogService);
    }

    @Test
    void testGetStatement_CalculatesBalancesCorrectly()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);
        user.setNume("Popescu");
        user.setPrenume("Ion");
        user.setCnp("1900101123456");

        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(10L);
        account.setUserId(1L);
        account.setIBAN("RO49AAAA1B31007593840001");
        account.setMoneda("RON");
        account.setSold(BigDecimal.valueOf(1000.00));
        account.setUser(user);

        when(accountRepo.findById(10L)).thenReturn(Optional.of(account));

        // Create a debit transfer of 200 RON and credit of 500 RON within last 7 days
        TransferJpaEntity debitTx = new TransferJpaEntity();
        debitTx.setId("tx-1");
        debitTx.setFromAccount(account);
        debitTx.setAmount(BigDecimal.valueOf(200.00));
        debitTx.setCurrency("RON");
        debitTx.setStatus("COMPLETED");
        debitTx.setInitiatedAt(Instant.now().minus(2, ChronoUnit.DAYS));

        TransferJpaEntity creditTx = new TransferJpaEntity();
        creditTx.setId("tx-2");
        creditTx.setToAccount(account);
        creditTx.setAmount(BigDecimal.valueOf(500.00));
        creditTx.setCurrency("RON");
        creditTx.setStatus("COMPLETED");
        creditTx.setInitiatedAt(Instant.now().minus(4, ChronoUnit.DAYS));

        when(transferRepo.findAll()).thenReturn(List.of(debitTx, creditTx));

        LocalDate toDate = LocalDate.now();
        LocalDate fromDate = toDate.minusDays(7);

        var statement = statementService.getStatement(1L, 10L, fromDate, toDate);

        assertNotNull(statement);
        assertEquals("RO49AAAA1B31007593840001", statement.iban());
        assertEquals("Popescu Ion", statement.accountHolder());
        assertEquals(BigDecimal.valueOf(500.00).setScale(2), statement.totalInflows());
        assertEquals(BigDecimal.valueOf(200.00).setScale(2), statement.totalOutflows());
        assertEquals(BigDecimal.valueOf(1000.00).setScale(2), statement.closingBalance());
        assertEquals(BigDecimal.valueOf(700.00).setScale(2), statement.openingBalance());
        assertEquals(2, statement.transactionCount());
    }

    @Test
    void testGetStatement_ExceedingOneYear_ThrowsException()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);

        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(10L);
        account.setUserId(1L);
        account.setUser(user);

        when(accountRepo.findById(10L)).thenReturn(Optional.of(account));

        LocalDate toDate = LocalDate.now();
        LocalDate fromDate = toDate.minusDays(400); // 400 days > 365 days

        assertThrows(IllegalArgumentException.class, () ->
                statementService.getStatement(1L, 10L, fromDate, toDate));
    }

    @Test
    void testGenerateStatementPdf_ReturnsValidPdfBytes()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);
        user.setNume("Popescu");
        user.setPrenume("Ion");
        user.setCnp("1900101123456");

        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(10L);
        account.setUserId(1L);
        account.setIBAN("RO49AAAA1B31007593840001");
        account.setMoneda("RON");
        account.setSold(BigDecimal.valueOf(1500.00));
        account.setUser(user);

        when(accountRepo.findById(10L)).thenReturn(Optional.of(account));
        when(transferRepo.findAll()).thenReturn(List.of());

        byte[] pdfBytes = statementService.generateStatementPdf(1L, 10L, LocalDate.now().minusDays(30), LocalDate.now());

        assertNotNull(pdfBytes);
        assertTrue(pdfBytes.length > 0);
        // PDF header magic bytes %PDF-
        assertEquals('%', (char) pdfBytes[0]);
        assertEquals('P', (char) pdfBytes[1]);
        assertEquals('D', (char) pdfBytes[2]);
        assertEquals('F', (char) pdfBytes[3]);
    }
}
