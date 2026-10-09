package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.DynamicLinkingService.Payment;
import com.intbank.service.StrongCustomerAuthService;
import com.intbank.service.StrongCustomerAuthService.ScaRequiredException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Setting up standing orders: only payments that can actually run are accepted. */
class ScheduledTransferControllerTest
{

    private static final long USER = 7L;
    private static final String RON = "RO26INTBRON0000000000001";
    private static final String EUR = "RO35INTBEUR0000000000003";
    private static final String PAYEE = "RO96INTBRON0000000000002";

    private ScheduledTransferJpaRepository scheduledRepo;
    private AccountJpaRepository accountRepo;
    private StrongCustomerAuthService sca;
    private ScheduledTransferController controller;

    @BeforeEach
    void setUp()
    {
        scheduledRepo = mock(ScheduledTransferJpaRepository.class);
        accountRepo = mock(AccountJpaRepository.class);
        sca = mock(StrongCustomerAuthService.class);
        controller = new ScheduledTransferController(scheduledRepo, accountRepo, mock(AuditLogService.class), sca);

        UserJpaEntity me = user(USER);
        AccountJpaEntity ron = account(1L, me, RON, "RON");
        AccountJpaEntity eur = account(2L, me, EUR, "EUR");
        when(accountRepo.findByUser_Id(USER)).thenReturn(List.of(ron, eur));
        when(accountRepo.findByIBAN(RON)).thenReturn(Optional.of(ron));
        when(accountRepo.findByIBAN(PAYEE)).thenReturn(Optional.of(account(3L, user(8L), PAYEE, "RON")));
        when(scheduledRepo.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    void savesAValidStandingOrderFromTheChosenAccount()
    {
        var response = controller.createScheduledTransfer(USER, body(" ro96 intb ron0 0000 0000 0002", 250.5, "MONTHLY", RON));

        assertEquals(201, response.getStatusCode().value());
        ArgumentCaptor<ScheduledTransferJpaEntity> saved = ArgumentCaptor.forClass(ScheduledTransferJpaEntity.class);
        verify(scheduledRepo).save(saved.capture());
        assertEquals(1L, saved.getValue().getFromAccountId());
        assertEquals(PAYEE, saved.getValue().getToIban());
        assertEquals(new BigDecimal("250.5"), saved.getValue().getAmount());
        assertEquals("RON", saved.getValue().getCurrency());
        assertEquals("ACTIVE", saved.getValue().getStatus());
    }

    @Test
    void rejectsOrdersThatCouldNeverBePaid()
    {
        expectCode(body("RO49AAAA1B31007593840000", 10, "MONTHLY", RON), BusinessRuleException.DESTINATION_NOT_FOUND);
        expectCode(body(PAYEE, 10, "MONTHLY", EUR), BusinessRuleException.CURRENCY_MISMATCH);
        expectCode(body(RON, 10, "MONTHLY", RON), BusinessRuleException.SAME_ACCOUNT);
        expectCode(body(PAYEE, 10, "MONTHLY", "RO49INTB0000000000000099"), BusinessRuleException.ACCOUNT_NOT_OWNED);
        expectCode(body(PAYEE, -5, "MONTHLY", RON), BusinessRuleException.INVALID_AMOUNT);
        expectCode(body(PAYEE, 1.234, "MONTHLY", RON), BusinessRuleException.INVALID_AMOUNT);
        verify(scheduledRepo, never()).save(any());
    }

    @Test
    void rejectsUnknownFrequenciesAndPastDates()
    {
        assertEquals(400, controller.createScheduledTransfer(USER, body(PAYEE, 10, "DAILY", RON)).getStatusCode().value());
        Map<String, Object> past = body(PAYEE, 10, "ONCE", RON);
        past.put("nextRunDate", LocalDate.now().minusDays(1).toString());
        assertEquals(400, controller.createScheduledTransfer(USER, past).getStatusCode().value());
        verify(scheduledRepo, never()).save(any());
    }

    @Test
    void aLargeStandingOrderNeedsThePinWhenItIsSetUp()
    {
        doThrow(new ScaRequiredException("sca-9", Instant.now(), new Payment(USER, RON, PAYEE, new BigDecimal("2000"), "RON")))
                .when(sca).authorize(any(), isNull(), isNull());

        var response = controller.createScheduledTransfer(USER, body(PAYEE, 2000, "MONTHLY", RON));

        assertEquals(428, response.getStatusCode().value());
        assertEquals("sca-9", response.getBody().get("challengeId"));
        verify(scheduledRepo, never()).save(any());
    }

    @Test
    void cancellingKeepsHistoryAndOnlyTouchesOwnOrders()
    {
        ScheduledTransferJpaEntity mine = new ScheduledTransferJpaEntity();
        mine.setId(5L);
        mine.setUserId(USER);
        mine.setStatus("ACTIVE");
        when(scheduledRepo.findById(5L)).thenReturn(Optional.of(mine));

        assertEquals(404, controller.cancelScheduledTransfer(99L, 5L).getStatusCode().value());
        assertEquals("ACTIVE", mine.getStatus());

        assertEquals(200, controller.cancelScheduledTransfer(USER, 5L).getStatusCode().value());
        assertEquals("CANCELLED", mine.getStatus());
    }

    private void expectCode(Map<String, Object> body, String code)
    {
        var response = controller.createScheduledTransfer(USER, body);
        assertEquals(400, response.getStatusCode().value(), code);
        assertEquals(code, response.getBody().get("code"));
    }

    private static Map<String, Object> body(String toIban, Number amount, String frequency, String fromIban)
    {
        Map<String, Object> body = new HashMap<>();
        body.put("toIban", toIban);
        body.put("beneficiaryName", "ANA IONESCU");
        body.put("reason", "Chirie");
        body.put("amount", amount);
        body.put("frequency", frequency);
        body.put("nextRunDate", LocalDate.now().plusDays(3).toString());
        body.put("fromIban", fromIban);
        return body;
    }

    private static UserJpaEntity user(long id)
    {
        UserJpaEntity u = new UserJpaEntity();
        u.setId(id);
        return u;
    }

    private static AccountJpaEntity account(long id, UserJpaEntity owner, String iban, String currency)
    {
        AccountJpaEntity a = new AccountJpaEntity();
        a.setId(id);
        a.setUser(owner);
        a.setIBAN(iban);
        a.setMoneda(currency);
        a.setSold(BigDecimal.TEN);
        return a;
    }
}
