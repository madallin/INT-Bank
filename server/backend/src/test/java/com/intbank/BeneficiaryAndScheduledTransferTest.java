package com.intbank;

import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.BeneficiaryJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.BeneficiaryJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import com.intbank.infrastructure.rest.BeneficiaryController;
import com.intbank.service.AuditLogService;
import com.intbank.service.ScheduledTransferService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BeneficiaryAndScheduledTransferTest
{

    @Mock
    private BeneficiaryJpaRepository beneficiaryRepo;

    @Mock
    private ScheduledTransferJpaRepository scheduledRepo;

    @Mock
    private AccountJpaRepository accountRepo;

    @Mock
    private TransferUseCase transferUseCase;

    @Mock
    private AuditLogService auditLogService;

    private BeneficiaryController beneficiaryController;
    private ScheduledTransferService scheduledTransferService;

    @BeforeEach
    void setUp()
    {
        beneficiaryController = new BeneficiaryController(beneficiaryRepo, auditLogService);
        scheduledTransferService = new ScheduledTransferService(scheduledRepo, accountRepo, transferUseCase, auditLogService);
    }

    @Test
    void testAddBeneficiary_Success()
    {
        when(beneficiaryRepo.findByUserIdAndIban(eq(1L), anyString())).thenReturn(Optional.empty());
        when(beneficiaryRepo.save(any(BeneficiaryJpaEntity.class))).thenAnswer(i -> i.getArgument(0));

        var response = beneficiaryController.addBeneficiary(1L, Map.of(
                "name", "Ion Popescu",
                "iban", "RO49BTRL0000123456789012"
        ));

        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue((Boolean) response.getBody().get("success"));
        verify(auditLogService, times(1)).log(eq(1L), eq("BENEFICIARY_ADDED"), anyString(), anyString());
    }

    @Test
    void testProcessDueScheduledTransfers_ExecutesAndAdvancesDate()
    {
        ScheduledTransferJpaEntity st = new ScheduledTransferJpaEntity();
        st.setId(100L);
        st.setUserId(1L);
        st.setFromAccountId(5L);
        st.setToIban("RO49BTRL0000123456789012");
        st.setBeneficiaryName("Ion Popescu");
        st.setAmount(BigDecimal.valueOf(250.00));
        st.setCurrency("RON");
        st.setReason("Chirie");
        st.setFrequency("MONTHLY");
        st.setNextRunDate(LocalDate.now());
        st.setStatus("ACTIVE");

        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual(eq("ACTIVE"), any(LocalDate.class)))
                .thenReturn(List.of(st));

        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(5L);
        account.setIBAN("RO49INTB0000111122223333");
        account.setMoneda("RON");
        when(accountRepo.findById(5L)).thenReturn(Optional.of(account));

        scheduledTransferService.processDueScheduledTransfers();

        verify(transferUseCase, times(1)).initiate(any(TransferUseCase.InitiateTransferRequest.class));
        assertEquals(LocalDate.now().plusMonths(1), st.getNextRunDate());
        verify(scheduledRepo, times(1)).save(st);
    }
}
