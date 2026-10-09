package com.intbank.service;

import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import com.intbank.infrastructure.security.AuthenticatedClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

/**
 * Runs due standing orders once a day.
 *
 * <p>Each payment is initiated on behalf of the customer who set it up: the run uses a
 * principal carrying that customer's id, so the normal ownership check still verifies the
 * source account belongs to them. Each schedule is handled on its own, so one failure never
 * affects another. A run that cannot be initiated is recorded and the customer is notified;
 * one-off payments become {@code FAILED}, recurring ones move on and pause after
 * {@link #MAX_CONSECUTIVE_FAILURES} failures in a row.
 */
@Service
public class ScheduledTransferService
{

    private static final Logger log = LoggerFactory.getLogger(ScheduledTransferService.class);

    public static final int MAX_CONSECUTIVE_FAILURES = 3;
    static final String SCHEDULER_DEVICE = "system:scheduler";

    private final ScheduledTransferJpaRepository scheduledRepo;
    private final AccountJpaRepository accountRepo;
    private final TransferUseCase transferUseCase;
    private final AuditLogService auditLogService;
    private final NotificationService notificationService;
    private final Clock clock;

    @Autowired
    public ScheduledTransferService(ScheduledTransferJpaRepository scheduledRepo,
                                    AccountJpaRepository accountRepo,
                                    TransferUseCase transferUseCase,
                                    AuditLogService auditLogService,
                                    NotificationService notificationService)
    {
        this(scheduledRepo, accountRepo, transferUseCase, auditLogService, notificationService, Clock.systemDefaultZone());
    }

    public ScheduledTransferService(ScheduledTransferJpaRepository scheduledRepo,
                                    AccountJpaRepository accountRepo,
                                    TransferUseCase transferUseCase,
                                    AuditLogService auditLogService,
                                    NotificationService notificationService,
                                    Clock clock)
    {
        this.scheduledRepo = scheduledRepo;
        this.accountRepo = accountRepo;
        this.transferUseCase = transferUseCase;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 6 * * ?") // Daily at 6:00 AM
    public void processDueScheduledTransfers()
    {
        LocalDate today = LocalDate.now(clock);
        List<ScheduledTransferJpaEntity> due = scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", today);
        log.info("Processing {} due scheduled transfers for {}", due.size(), today);

        for (ScheduledTransferJpaEntity st : due)
        {
            try
            {
                runOnce(st, today);
                recordSuccess(st, today);
            }
            catch (Exception e)
            {
                log.warn("Scheduled transfer {} could not be initiated: {}", st.getId(), e.getMessage());
                recordFailure(st, today, e.getMessage());
            }
            scheduledRepo.save(st);
        }
    }

    private void runOnce(ScheduledTransferJpaEntity st, LocalDate today)
    {
        AccountJpaEntity fromAccount = accountRepo.findById(st.getFromAccountId())
                .orElseThrow(() -> new IllegalStateException("Contul sursă nu mai există"));

        SecurityContext previous = SecurityContextHolder.getContext();
        SecurityContext asOwner = SecurityContextHolder.createEmptyContext();
        asOwner.setAuthentication(new UsernamePasswordAuthenticationToken(
                new AuthenticatedClient(SCHEDULER_DEVICE, st.getUserId(), List.of("ROLE_USER")),
                null, List.of(new SimpleGrantedAuthority("ROLE_USER"))));
        SecurityContextHolder.setContext(asOwner);
        try
        {
            transferUseCase.initiate(new TransferUseCase.InitiateTransferRequest(
                    fromAccount.getIBAN(),
                    st.getToIban(),
                    st.getAmount(),
                    st.getCurrency(),
                    st.getReason() + " (Programata)",
                    st.getBeneficiaryName(),
                    fromAccount.getUser() != null ? fromAccount.getUser().getNume() + " " + fromAccount.getUser().getPrenume() : "Titular",
                    // One key per schedule and due date: a re-run of the same day is a no-op.
                    "sched-" + st.getId() + "-" + st.getNextRunDate()
            ));
        }
        finally
        {
            SecurityContextHolder.setContext(previous);
        }
    }

    private void recordSuccess(ScheduledTransferJpaEntity st, LocalDate today)
    {
        st.setLastRunAt(clock.instant());
        st.setLastError(null);
        st.setConsecutiveFailures(0);
        auditLogService.log(st.getUserId(), "SCHEDULED_TRANSFER_EXECUTED",
                "Executed scheduled transfer ID " + st.getId() + " (" + st.getAmount() + " " + st.getCurrency() + " to " + st.getToIban() + ")", "127.0.0.1");
        advance(st, today, "COMPLETED");
    }

    private void recordFailure(ScheduledTransferJpaEntity st, LocalDate today, String reason)
    {
        String error = reason == null ? "Eroare necunoscută" : reason.length() > 255 ? reason.substring(0, 255) : reason;
        st.setLastRunAt(clock.instant());
        st.setLastError(error);
        st.setConsecutiveFailures(st.getConsecutiveFailures() + 1);
        auditLogService.log(st.getUserId(), "SCHEDULED_TRANSFER_FAILED",
                "Scheduled transfer ID " + st.getId() + " failed: " + error, "127.0.0.1");

        String title = "Plata programată nu a fost efectuată";
        if ("ONCE".equalsIgnoreCase(st.getFrequency()))
        {
            st.setStatus("FAILED");
            notificationService.notify(st.getUserId(), title,
                    "Plata către " + st.getBeneficiaryName() + " nu a putut fi efectuată: " + error, "SYSTEM");
            return;
        }
        advance(st, today, null);
        if (st.getConsecutiveFailures() >= MAX_CONSECUTIVE_FAILURES)
        {
            st.setStatus("PAUSED");
            notificationService.notify(st.getUserId(), title,
                    "Plata către " + st.getBeneficiaryName() + " a eșuat de " + st.getConsecutiveFailures()
                            + " ori la rând și a fost suspendată: " + error, "SYSTEM");
        }
        else
        {
            notificationService.notify(st.getUserId(), title,
                    "Plata către " + st.getBeneficiaryName() + " nu a putut fi efectuată: " + error
                            + ". Vom reîncerca la " + st.getNextRunDate() + ".", "SYSTEM");
        }
    }

    /** Moves to the first occurrence after today (missed periods are not paid twice). */
    private static void advance(ScheduledTransferJpaEntity st, LocalDate today, String statusWhenOnce)
    {
        if ("ONCE".equalsIgnoreCase(st.getFrequency()))
        {
            if (statusWhenOnce != null) st.setStatus(statusWhenOnce);
            return;
        }
        LocalDate next = st.getNextRunDate();
        while (!next.isAfter(today))
        {
            next = "WEEKLY".equalsIgnoreCase(st.getFrequency()) ? next.plusWeeks(1) : next.plusMonths(1);
        }
        st.setNextRunDate(next);
    }
}
