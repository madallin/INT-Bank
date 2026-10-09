package com.intbank;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.NotificationJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.NotificationJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import com.intbank.service.AnalyticsService;
import com.intbank.service.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.YearMonth;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class NotificationAndAnalyticsTest
{

    @Mock
    private NotificationJpaRepository notificationRepo;

    @Mock
    private AccountJpaRepository accountRepo;

    @Mock
    private TransferJpaRepository transferRepo;

    private NotificationService notificationService;
    private AnalyticsService analyticsService;

    @BeforeEach
    void setUp()
    {
        notificationService = new NotificationService(notificationRepo);
        analyticsService = new AnalyticsService(accountRepo, transferRepo);
    }

    @Test
    void testNotification_CreationAndUnreadCount()
    {
        when(notificationRepo.save(any(NotificationJpaEntity.class))).thenAnswer(i -> i.getArgument(0));
        when(notificationRepo.countByUserIdAndIsReadFalse(1L)).thenReturn(3L);

        var n = notificationService.notify(1L, "Transfer Primit", "Ai primit 100 RON", "TRANSFER_RECEIVED");
        assertNotNull(n);
        assertEquals(1L, n.getUserId());
        assertEquals("TRANSFER_RECEIVED", n.getType());
        assertFalse(n.isRead());

        long unread = notificationService.getUnreadCount(1L);
        assertEquals(3L, unread);
    }

    @Test
    void testNotification_SsePush()
    {
        when(notificationRepo.save(any(NotificationJpaEntity.class))).thenAnswer(i -> i.getArgument(0));

        // Test SSE emitter registration
        var emitter = notificationService.registerEmitter(1L);
        assertNotNull(emitter);

        // Test broadcast on notify
        var n = notificationService.notify(1L, "Transfer Primit", "Ai primit 250 RON", "TRANSFER_RECEIVED");
        assertNotNull(n);
    }

    @Test
    void testAnalytics_CategorizationRules()
    {
        assertEquals("ALIMENTE", AnalyticsService.categorize("Cumparaturi Mega Image", "RO49..."));
        assertEquals("UTILITATI", AnalyticsService.categorize("Plata Factura Digi", "RO49..."));
        assertEquals("RESTAURANTE", AnalyticsService.categorize("Comanda Glovo", "RO49..."));
        assertEquals("TRANSPORT", AnalyticsService.categorize("Cursa Uber", "RO49..."));
        assertEquals("DIVERTISMENT", AnalyticsService.categorize("Abonament Netflix", "RO49..."));
        assertEquals("ALTELE", AnalyticsService.categorize("Rambursare imprumut", "RO49..."));
    }

    @Test
    void testAnalytics_CategorizationMatchesWholeWordsWithoutDiacritics()
    {
        assertEquals("UTILITATI", AnalyticsService.categorize("Factură Enel octombrie", null));
        assertEquals("UTILITATI", AnalyticsService.categorize("Întreținere bloc", null));
        assertEquals("RESTAURANTE", AnalyticsService.categorize("Cafea cu Ana", null));
        assertEquals("RESTAURANTE", AnalyticsService.categorize("Comanda Bolt Food", null), "not transport");
        assertEquals("TRANSPORT", AnalyticsService.categorize("Bolt aeroport", null));
        // Words that merely contain a keyword are not that category.
        assertEquals("ALTELE", AnalyticsService.categorize("Abonament digital", null));
        assertEquals("ALTELE", AnalyticsService.categorize("Profit share", null));
        assertEquals("ALTELE", AnalyticsService.categorize("Cadou Simeon", null));
        assertEquals("ALTELE", AnalyticsService.categorize("Imobiliare", null));
        // The IBAN never decides: random letters in it could spell a keyword.
        assertEquals("ALTELE", AnalyticsService.categorize("Transfer", "RO12BAR0MOL0GAZ"));
        assertEquals("ALTELE", AnalyticsService.categorize(null, null));
        assertEquals("ALTELE", AnalyticsService.categorize("   ", null));
    }

    @Test
    void testAnalytics_MonthlySpendingCalculation()
    {
        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(10L);
        account.setUser(userWithId(1L));
        account.setMoneda("RON");
        when(accountRepo.findById(10L)).thenReturn(Optional.of(account));

        TransferJpaEntity tx1 = new TransferJpaEntity();
        tx1.setFromAccount(account);
        tx1.setAmount(BigDecimal.valueOf(150.00));
        tx1.setReason("Cumparaturi Lidl");
        tx1.setStatus("COMPLETED");
        tx1.setInitiatedAt(Instant.now());

        TransferJpaEntity tx2 = new TransferJpaEntity();
        tx2.setFromAccount(account);
        tx2.setAmount(BigDecimal.valueOf(50.00));
        tx2.setReason("Cursa Uber");
        tx2.setStatus("COMPLETED");
        tx2.setInitiatedAt(Instant.now());

        when(transferRepo.findByFromAccount_IdOrToAccount_IdOrderByInitiatedAtDesc(anyLong(), anyLong())).thenReturn(List.of(tx1, tx2));

        var response = analyticsService.getMonthlySpending(1L, 10L, YearMonth.now());

        assertNotNull(response);
        assertEquals(BigDecimal.valueOf(200.00).setScale(2), response.totalSpent());
        assertEquals(2, response.totalTransactions());
        assertEquals("Alimente & Supermarket", response.topCategory());
    }

    private static com.intbank.infrastructure.persistence.entity.UserJpaEntity userWithId(Long id)
    {
        var user = new com.intbank.infrastructure.persistence.entity.UserJpaEntity();
        user.setId(id);
        return user;
    }
}
