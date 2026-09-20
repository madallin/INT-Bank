package com.intbank.service;

import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.ScheduledTransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.ScheduledTransferJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
public class ScheduledTransferService
{

    private static final Logger log = LoggerFactory.getLogger(ScheduledTransferService.class);

    private final ScheduledTransferJpaRepository scheduledRepo;
    private final AccountJpaRepository accountRepo;
    private final TransferUseCase transferUseCase;
    private final AuditLogService auditLogService;

    public ScheduledTransferService(ScheduledTransferJpaRepository scheduledRepo,
                                   AccountJpaRepository accountRepo,
                                   TransferUseCase transferUseCase,
                                   AuditLogService auditLogService)
    {
        this.scheduledRepo = scheduledRepo;
        this.accountRepo = accountRepo;
        this.transferUseCase = transferUseCase;
        this.auditLogService = auditLogService;
    }

    @Scheduled(cron = "0 0 6 * * ?") // Daily at 6:00 AM
    @Transactional
    public void processDueScheduledTransfers()
    {
        LocalDate today = LocalDate.now();
        List<ScheduledTransferJpaEntity> due = scheduledRepo.findByStatusAndNextRunDateLessThanEqual("ACTIVE", today);
        log.info("Processing {} due scheduled transfers for {}", due.size(), today);

        for (ScheduledTransferJpaEntity st : due)
        {
            try
            {
                var accountOpt = accountRepo.findById(st.getFromAccountId());
                if (accountOpt.isEmpty())
                {
                    log.error("Scheduled transfer {} failed: Source account not found", st.getId());
                    continue;
                }
                AccountJpaEntity fromAccount = accountOpt.get();

                String idempotencyKey = "sched-" + st.getId() + "-" + today;

                transferUseCase.initiate(new TransferUseCase.InitiateTransferRequest(
                        fromAccount.getIBAN(),
                        st.getToIban(),
                        st.getAmount(),
                        st.getCurrency(),
                        st.getReason() + " (Programata)",
                        st.getBeneficiaryName(),
                        fromAccount.getUser() != null ? fromAccount.getUser().getNume() + " " + fromAccount.getUser().getPrenume() : "Titular",
                        idempotencyKey
                ));

                auditLogService.log(st.getUserId(), "SCHEDULED_TRANSFER_EXECUTED",
                        "Executed scheduled transfer ID " + st.getId() + " (" + st.getAmount() + " " + st.getCurrency() + " to " + st.getToIban() + ")", "127.0.0.1");

                // Update next run date or mark completed
                if ("ONCE".equalsIgnoreCase(st.getFrequency()))
                {
                    st.setStatus("COMPLETED");
                }
                else if ("WEEKLY".equalsIgnoreCase(st.getFrequency()))
                {
                    st.setNextRunDate(st.getNextRunDate().plusWeeks(1));
                }
                else // MONTHLY
                {
                    st.setNextRunDate(st.getNextRunDate().plusMonths(1));
                }
                scheduledRepo.save(st);
            }
            catch (Exception e)
            {
                log.error("Failed to execute scheduled transfer {}", st.getId(), e);
            }
        }
    }
}
