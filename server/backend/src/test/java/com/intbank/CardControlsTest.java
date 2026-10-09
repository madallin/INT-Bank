package com.intbank;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.CardJpaRepository;
import com.intbank.infrastructure.rest.CardController;
import com.intbank.service.AuditLogService;
import com.intbank.service.CryptoService;
import com.intbank.service.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Audit finding F4: freeze, unfreeze and limits used to return success without saving
 * anything, and the card list always reported an active card with a 5,000 limit.
 */
class CardControlsTest
{

    private static final long USER = 7L;
    private static final long CARD = 11L;

    private CardJpaEntity card;
    private CardJpaRepository cardRepo;
    private NotificationService notificationService;
    private CardController controller;

    @BeforeEach
    void setUp()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(USER);
        AccountJpaEntity account = new AccountJpaEntity();
        account.setId(3L);
        card = new CardJpaEntity();
        card.setId(CARD);
        card.setUser(user);
        card.setAccount(account);
        card.setNumarCard("4111111111111111");
        card.setDataExpirare("12/29");
        card.setDetinator("ION POPESCU");
        card.setToken("tok-1");

        cardRepo = mock(CardJpaRepository.class);
        when(cardRepo.findById(CARD)).thenReturn(Optional.of(card));
        when(cardRepo.findByUser_Id(USER)).thenReturn(List.of(card));
        notificationService = mock(NotificationService.class);
        controller = new CardController(cardRepo, mock(CryptoService.class), mock(AuditLogService.class), notificationService);
    }

    @Test
    void freezeIsPersistedAndReportedByTheCardList()
    {
        assertEquals(200, controller.freezeCard(USER, CARD).getStatusCode().value());
        verify(cardRepo).save(card);
        assertEquals(CardJpaEntity.STATUS_FROZEN, card.getStatus());
        assertNotNull(card.getStatusChangedAt());

        Map<String, Object> listed = onlyCard();
        assertEquals(true, listed.get("isBlocked"));
        assertEquals("frozen", listed.get("status"));

        controller.unfreezeCard(USER, CARD);
        assertEquals(false, onlyCard().get("isBlocked"));
        assertEquals("active", onlyCard().get("status"));
    }

    @Test
    void repeatingAFreezeDoesNotResendTheSecurityAlert()
    {
        controller.freezeCard(USER, CARD);
        controller.freezeCard(USER, CARD);

        verify(notificationService, times(1)).notify(eq(USER), anyString(), anyString(), eq("SECURITY_ALERT"));
        verify(cardRepo, times(1)).save(card);
    }

    @Test
    void limitsAndChannelsArePersistedAndListed()
    {
        var response = controller.updateCardLimits(USER, CARD,
                Map.of("spendingLimit", 1234.5, "onlinePayments", false, "contactless", true));

        assertEquals(200, response.getStatusCode().value());
        verify(cardRepo).save(card);
        Map<String, Object> listed = onlyCard();
        assertEquals(0, new BigDecimal("1234.50").compareTo((BigDecimal) listed.get("spendingLimit")));
        assertEquals(false, listed.get("onlinePayments"));
        assertEquals(true, listed.get("contactless"));
    }

    @Test
    void invalidLimitsAreRejectedAndNothingIsSaved()
    {
        for (Object bad : List.of(0, -10, "abc", 100_000.01))
        {
            var response = controller.updateCardLimits(USER, CARD, Map.of("spendingLimit", bad));
            assertEquals(400, response.getStatusCode().value(), "limit " + bad);
        }
        assertEquals(400, controller.updateCardLimits(USER, CARD, Map.of("onlinePayments", "yes")).getStatusCode().value());
        verify(cardRepo, never()).save(any());
        assertEquals(0, CardJpaEntity.DEFAULT_SPENDING_LIMIT.compareTo(card.getSpendingLimit()));
    }

    @Test
    void anotherCustomersCardIsNotFound()
    {
        assertEquals(404, controller.freezeCard(99L, CARD).getStatusCode().value());
        assertFalse(card.isFrozen());
        verify(cardRepo, never()).save(any());
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> onlyCard()
    {
        var body = controller.getCards(USER).getBody();
        assertNotNull(body);
        var cards = (List<Map<String, Object>>) body.get("cards");
        assertEquals(1, cards.size());
        return cards.get(0);
    }
}
