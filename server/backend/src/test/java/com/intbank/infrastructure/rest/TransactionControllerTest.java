package com.intbank.infrastructure.rest;

import com.intbank.core.domain.exception.BusinessRuleException;
import com.intbank.core.domain.vo.TransferStatus;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import com.intbank.service.DynamicLinkingService.Payment;
import com.intbank.service.StrongCustomerAuthService;
import com.intbank.service.StrongCustomerAuthService.ScaRequiredException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** The app's transfer endpoint and transaction history. */
class TransactionControllerTest
{

    private static final long USER = 7L;
    private static final String RON_IBAN = "RO26INTBRON0000000000001";
    private static final String EUR_IBAN = "RO35INTBEUR0000000000003";
    private static final String PAYEE = "RO96INTBRON0000000000002";

    private TransferUseCase transferUseCase;
    private AccountJpaRepository accountRepo;
    private TransferJpaRepository transferRepo;
    private StrongCustomerAuthService sca;
    private TransactionController controller;
    private AccountJpaEntity ron;
    private AccountJpaEntity eur;

    @BeforeEach
    void setUp()
    {
        transferUseCase = mock(TransferUseCase.class);
        accountRepo = mock(AccountJpaRepository.class);
        transferRepo = mock(TransferJpaRepository.class);
        sca = mock(StrongCustomerAuthService.class);
        controller = new TransactionController(transferUseCase, accountRepo, transferRepo, sca, null, null);

        UserJpaEntity user = new UserJpaEntity();
        user.setId(USER);
        user.setNume("Popescu");
        user.setPrenume("Ion");
        ron = account(1L, user, RON_IBAN, "RON");
        eur = account(2L, user, EUR_IBAN, "EUR");
        when(accountRepo.findByUser_Id(USER)).thenReturn(List.of(ron, eur));
        when(transferUseCase.initiate(any())).thenReturn(
                new TransferUseCase.InitiateTransferResponse("TRK-1", TransferStatus.PENDING, "ok"));
    }

    @Test
    void sendsFromTheChosenAccountInItsCurrencyWithANormalizedIban()
    {
        var response = controller.userTransfer(USER, "idem-1", body(" ro96 intb ron0 0000 0000 0002 ", 150.25, EUR_IBAN));

        assertEquals(200, response.getStatusCode().value());
        assertEquals("TRK-1", response.getBody().get("trackingId"));
        ArgumentCaptor<TransferUseCase.InitiateTransferRequest> request = ArgumentCaptor.forClass(TransferUseCase.InitiateTransferRequest.class);
        verify(transferUseCase).initiate(request.capture());
        assertEquals(EUR_IBAN, request.getValue().fromIban());
        assertEquals("EUR", request.getValue().currency());
        assertEquals(PAYEE, request.getValue().toIban());
        assertEquals(new BigDecimal("150.25"), request.getValue().amount());
        assertEquals("idem-1", request.getValue().idempotencyKey());
        assertEquals("Popescu Ion", request.getValue().senderName());
    }

    @Test
    void refusesASourceAccountTheCustomerDoesNotOwn()
    {
        var response = controller.userTransfer(USER, "idem-2", body(PAYEE, 10, "RO49INTB0000000000000099"));

        assertEquals(400, response.getStatusCode().value());
        assertEquals(BusinessRuleException.ACCOUNT_NOT_OWNED, response.getBody().get("code"));
        verifyNoInteractions(transferUseCase);
    }

    @Test
    void aLargePaymentReturnsTheChallengeInsteadOfMovingMoney()
    {
        Payment payment = new Payment(USER, RON_IBAN, PAYEE, new BigDecimal("1500"), "RON");
        doThrow(new ScaRequiredException("sca-1", Instant.parse("2026-10-04T10:05:00Z"), payment))
                .when(sca).authorize(any(), isNull(), isNull());

        var response = controller.userTransfer(USER, "idem-3", body(PAYEE, 1500, RON_IBAN));

        assertEquals(428, response.getStatusCode().value());
        assertEquals("SCA_REQUIRED", response.getBody().get("code"));
        assertEquals("sca-1", response.getBody().get("challengeId"));
        assertEquals(PAYEE, response.getBody().get("toIban"));
        verifyNoInteractions(transferUseCase);
    }

    @Test
    void passesTheChallengeAndPinToStepUpThenPays()
    {
        Map<String, Object> body = body(PAYEE, 1500, RON_IBAN);
        body.put("scaChallengeId", "sca-1");
        body.put("scaPin", "246802");

        assertEquals(200, controller.userTransfer(USER, "idem-4", body).getStatusCode().value());

        ArgumentCaptor<Payment> payment = ArgumentCaptor.forClass(Payment.class);
        verify(sca).authorize(payment.capture(), eq("sca-1"), eq("246802"));
        assertEquals(new Payment(USER, RON_IBAN, PAYEE, new BigDecimal("1500"), "RON"), payment.getValue());
        verify(transferUseCase).initiate(any());
    }

    @Test
    void wrongPinIsABadRequestAndLockedPinIsLocked()
    {
        doThrow(new BusinessRuleException(BusinessRuleException.SCA_PIN_INVALID, "PIN incorect", Map.of("remainingAttempts", 2)))
                .doThrow(new BusinessRuleException(BusinessRuleException.SCA_LOCKED, "PIN blocat"))
                .when(sca).authorize(any(), any(), any());

        var wrong = controller.userTransfer(USER, "k", body(PAYEE, 1500, RON_IBAN));
        assertEquals(400, wrong.getStatusCode().value());
        assertEquals(2, wrong.getBody().get("remainingAttempts"));

        var locked = controller.userTransfer(USER, "k", body(PAYEE, 1500, RON_IBAN));
        assertEquals(423, locked.getStatusCode().value());
        assertEquals(BusinessRuleException.SCA_LOCKED, locked.getBody().get("code"));
        verifyNoInteractions(transferUseCase);
    }

    @Test
    void ruleViolationsFromTheUseCaseKeepTheirCode()
    {
        when(transferUseCase.initiate(any())).thenThrow(
                new BusinessRuleException(BusinessRuleException.DESTINATION_NOT_FOUND, "Nu există"));

        var response = controller.userTransfer(USER, "k", body(PAYEE, 10, RON_IBAN));

        assertEquals(400, response.getStatusCode().value());
        assertEquals(BusinessRuleException.DESTINATION_NOT_FOUND, response.getBody().get("code"));
    }

    @Test
    void missingFieldsAreRejected()
    {
        var response = controller.userTransfer(USER, null, new HashMap<>(Map.of("iban", PAYEE)));
        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(transferUseCase, sca);
    }

    @Test
    @SuppressWarnings("unchecked")
    void historyShowsOnlyThisAccountsTransfersNewestFirstWithDirection()
    {
        when(accountRepo.findById(1L)).thenReturn(Optional.of(ron));
        AccountJpaEntity other = account(9L, new UserJpaEntity(), PAYEE, "RON");
        when(transferRepo.findByFromAccount_IdOrToAccount_IdOrderByInitiatedAtDesc(anyLong(), anyLong())).thenReturn(List.of(
                transfer("t-out", ron, other, "100", Instant.parse("2026-10-01T10:00:00Z")),
                transfer("t-in", other, ron, "40", Instant.parse("2026-10-03T10:00:00Z")),
                transfer("t-unrelated", other, eur, "5", Instant.parse("2026-10-04T10:00:00Z"))));

        var body = controller.getTransactions(USER, 1L).getBody();
        var list = (List<Map<String, Object>>) body.get("transactions");

        assertEquals(List.of("t-in", "t-out"), list.stream().map(t -> t.get("id")).toList());
        assertEquals("CREDIT", list.get(0).get("type"));
        assertEquals("DEBIT", list.get(1).get("type"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void historyTellsTheAppEachTransactionsCategory()
    {
        when(accountRepo.findById(1L)).thenReturn(Optional.of(ron));
        AccountJpaEntity other = account(9L, userWithId(99L), PAYEE, "RON");
        TransferJpaEntity bill = transfer("t-bill", ron, other, "80", Instant.parse("2026-10-04T10:00:00Z"));
        bill.setReason("Factură Enel");
        TransferJpaEntity plain = transfer("t-plain", ron, other, "10", Instant.parse("2026-10-03T10:00:00Z"));
        TransferJpaEntity received = transfer("t-in", other, ron, "40", Instant.parse("2026-10-02T10:00:00Z"));
        received.setReason("Factură Enel"); // money in is "received", whatever the details say
        TransferJpaEntity own = transfer("t-own", ron, eur, "5", Instant.parse("2026-10-01T10:00:00Z"));
        when(transferRepo.findByFromAccount_IdOrToAccount_IdOrderByInitiatedAtDesc(anyLong(), anyLong()))
                .thenReturn(List.of(bill, plain, received, own));

        var list = (List<Map<String, Object>>) controller.getTransactions(USER, 1L).getBody().get("transactions");

        assertEquals(List.of("UTILITATI", "ALTELE", "INCOMING", "OWN_ACCOUNTS"),
                list.stream().map(t -> t.get("category")).toList());
    }

    @Test
    void historyOfAnotherCustomersAccountIsNotFound()
    {
        AccountJpaEntity foreign = account(9L, userWithId(99L), PAYEE, "RON");
        when(accountRepo.findById(9L)).thenReturn(Optional.of(foreign));

        assertEquals(404, controller.getTransactions(USER, 9L).getStatusCode().value());
        verifyNoInteractions(transferRepo);
    }

    private static Map<String, Object> body(String iban, Number amount, String fromIban)
    {
        Map<String, Object> body = new HashMap<>();
        body.put("iban", iban);
        body.put("amount", amount);
        body.put("reason", "Chirie");
        body.put("beneficiaryName", "ANA IONESCU");
        body.put("fromIban", fromIban);
        return body;
    }

    private static AccountJpaEntity account(long id, UserJpaEntity user, String iban, String currency)
    {
        AccountJpaEntity a = new AccountJpaEntity();
        a.setId(id);
        a.setUser(user);
        a.setIBAN(iban);
        a.setMoneda(currency);
        a.setSold(new BigDecimal("1000"));
        return a;
    }

    private static UserJpaEntity userWithId(long id)
    {
        UserJpaEntity u = new UserJpaEntity();
        u.setId(id);
        return u;
    }

    private static TransferJpaEntity transfer(String id, AccountJpaEntity from, AccountJpaEntity to, String amount, Instant at)
    {
        TransferJpaEntity t = new TransferJpaEntity();
        t.setId(id);
        t.setFromAccount(from);
        t.setToAccount(to);
        t.setAmount(new BigDecimal(amount));
        t.setCurrency("RON");
        t.setReason("test");
        t.setStatus("COMPLETED");
        t.setInitiatedAt(at);
        return t;
    }
}
