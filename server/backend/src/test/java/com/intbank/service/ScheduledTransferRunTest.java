package com.intbank.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.application.usecase.InitiateTransferUseCase;
import com.intbank.core.port.out.AccountRepository;
import com.intbank.core.port.out.AccountRepository.AccountProjection;
import com.intbank.core.port.out.EventPublisher;
import com.intbank.core.port.out.TransferRepository;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.OutboxJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.OutboxJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Audit finding F5: the daily job used to call the transfer use case without any signed-in
 * customer, so every run threw and was swallowed. These tests use the real
 * {@link InitiateTransferUseCase} (only storage is mocked) so that check is exercised.
 */
class ScheduledTransferRunTest
{

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 5);
    private static final String FROM = "RO26INTBRON0000000000001";
    private static final String TO = "RO96INTBRON0000000000002";

    private ScheduledTransferJpaRepository scheduledRepo;
    private AccountRepository accountPort;
    private OutboxJpaRepository outboxRepo;
    private NotificationService notificationService;
    private AmlVelocityService aml;
    private ScheduledTransferService scheduler;

    @BeforeEach
    void setUp()
    {
        scheduledRepo = mock(ScheduledTransferJpaRepository.class);
        accountPort = mock(AccountRepository.class);
        outboxRepo = mock(OutboxJpaRepository.class);
        notificationService = mock(NotificationService.class);
        aml = mock(AmlVelocityService.class);
        IdempotencyService idempotency = mock(IdempotencyService.class);
        AccountJpaRepository accountRepo = mock(AccountJpaRepository.class);

        when(aml.evaluateTransfer(anyLong(), any(), any()))
                .thenReturn(new AmlVelocityService.AmlResult(AmlVelocityService.RiskAssessment.PASS, false, "OK"));
        when(idempotency.beginOrGet(anyString(), anyLong(), anyString()))
                .thenReturn(new IdempotencyService.Decision(IdempotencyService.Outcome.PROCEED, null));
        when(accountPort.findByIban(FROM)).thenReturn(Optional.of(new AccountProjection("1", 7L, FROM, "RON", new BigDecimal("5000"))));
        when(accountPort.findByIban(TO)).thenReturn(Optional.of(new AccountProjection("2", 8L, TO, "RON", BigDecimal.ZERO)));

        UserJpaEntity owner = new UserJpaEntity();
        owner.setId(7L);
        owner.setNume("Popescu");
        owner.setPrenume("Ion");
        AccountJpaEntity source = new AccountJpaEntity();
        source.setId(1L);
        source.setUser(owner);
        source.setIBAN(FROM);
        source.setMoneda("RON");
        when(accountRepo.findById(1L)).thenReturn(Optional.of(source));

        var useCase = new InitiateTransferUseCase(mock(EventPublisher.class), accountPort, mock(TransferRepository.class),
                outboxRepo, idempotency, new ObjectMapper().findAndRegisterModules(), aml, mock(AuditLogService.class));
        Clock clock = Clock.fixed(TODAY.atStartOfDay(ZoneOffset.UTC).toInstant(), ZoneId.of("UTC"));
        scheduler = new ScheduledTransferService(scheduledRepo, accountRepo, useCase, mock(AuditLogService.class),
                notificationService, clock);
    }

    @Test
    void aDuePaymentIsInitiatedOnBehalfOfItsOwner()
    {
        var st = schedule("MONTHLY", TODAY);
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", TODAY)).thenReturn(List.of(st));

        scheduler.processDueScheduledTransfers();

        ArgumentCaptor<OutboxJpaEntity> outbox = ArgumentCaptor.forClass(OutboxJpaEntity.class);
        verify(outboxRepo).save(outbox.capture());
        assertTrue(outbox.getValue().getPayload().contains(TO), "transfer event published for the payee");
        assertEquals(LocalDate.of(2026, 11, 5), st.getNextRunDate());
        assertEquals("ACTIVE", st.getStatus());
        assertEquals(0, st.getConsecutiveFailures());
        assertNull(st.getLastError());
        assertNull(SecurityContextHolder.getContext().getAuthentication(), "the owner's identity must not leak past the run");
    }

    @Test
    void aOneOffPaymentCompletes()
    {
        var st = schedule("ONCE", TODAY);
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", TODAY)).thenReturn(List.of(st));

        scheduler.processDueScheduledTransfers();

        assertEquals("COMPLETED", st.getStatus());
    }

    @Test
    void aScheduleCannotPayFromAnotherCustomersAccount()
    {
        var st = schedule("ONCE", TODAY);
        st.setUserId(99L); // tampered row: account 1 belongs to customer 7
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", TODAY)).thenReturn(List.of(st));

        scheduler.processDueScheduledTransfers();

        verify(outboxRepo, never()).save(any());
        assertEquals("FAILED", st.getStatus());
    }

    @Test
    void failuresAreRecordedNotifiedAndPauseARecurringPaymentAfterThree()
    {
        when(aml.evaluateTransfer(anyLong(), any(), any())).thenReturn(new AmlVelocityService.AmlResult(
                AmlVelocityService.RiskAssessment.DAILY_LIMIT_EXCEEDED, false, "Limita zilnica depasita"));
        var st = schedule("WEEKLY", TODAY);
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual(eq("ACTIVE"), any())).thenReturn(List.of(st));

        for (int run = 1; run <= 3; run++)
        {
            scheduler.processDueScheduledTransfers();
            assertEquals(run, st.getConsecutiveFailures());
            assertTrue(st.getLastError().contains("Limita zilnica"));
            st.setNextRunDate(TODAY); // due again
        }

        assertEquals("PAUSED", st.getStatus());
        verify(notificationService, times(3)).notify(eq(7L), anyString(), anyString(), eq("SYSTEM"));
        verify(outboxRepo, never()).save(any());
    }

    @Test
    void oneFailingScheduleDoesNotStopTheOthers()
    {
        var broken = schedule("ONCE", TODAY);
        broken.setId(1L);
        broken.setFromAccountId(404L); // source account closed
        var fine = schedule("ONCE", TODAY);
        fine.setId(2L);
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", TODAY)).thenReturn(List.of(broken, fine));

        scheduler.processDueScheduledTransfers();

        assertEquals("FAILED", broken.getStatus());
        assertEquals("COMPLETED", fine.getStatus());
        verify(scheduledRepo).save(broken);
        verify(scheduledRepo).save(fine);
    }

    @Test
    void missedPeriodsAreNotPaidTwice()
    {
        var st = schedule("MONTHLY", TODAY.minusMonths(3));
        when(scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", TODAY)).thenReturn(List.of(st));

        scheduler.processDueScheduledTransfers();

        verify(outboxRepo, times(1)).save(any());
        assertTrue(st.getNextRunDate().isAfter(TODAY));
    }

    private static ScheduledTransferJpaEntity schedule(String frequency, LocalDate nextRun)
    {
        ScheduledTransferJpaEntity st = new ScheduledTransferJpaEntity();
        st.setId(100L);
        st.setUserId(7L);
        st.setFromAccountId(1L);
        st.setToIban(TO);
        st.setBeneficiaryName("Ana Ionescu");
        st.setAmount(new BigDecimal("250.00"));
        st.setCurrency("RON");
        st.setReason("Chirie");
        st.setFrequency(frequency);
        st.setNextRunDate(nextRun);
        st.setStatus("ACTIVE");
        return st;
    }
}
