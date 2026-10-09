package com.intbank.service;

import com.intbank.core.domain.vo.AccountNumbers;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.CardJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Opening the first account and card for an approved customer. */
class BankingServiceTest
{

    private AccountJpaRepository accountRepo;
    private CardJpaRepository cardRepo;
    private CryptoService cryptoService;
    private BankingService service;

    @BeforeEach
    void setUp()
    {
        accountRepo = mock(AccountJpaRepository.class);
        cardRepo = mock(CardJpaRepository.class);
        UserJpaRepository userRepo = mock(UserJpaRepository.class);
        cryptoService = mock(CryptoService.class);
        UserJpaEntity user = new UserJpaEntity();
        user.setId(5L);
        user.setNume("Popescu");
        user.setPrenume("Ion");
        when(userRepo.findById(5L)).thenReturn(Optional.of(user));
        when(accountRepo.save(any())).thenAnswer(i -> withId(i.getArgument(0), 40L));
        when(cardRepo.save(any())).thenAnswer(i -> {
            CardJpaEntity card = i.getArgument(0);
            card.setId(77L);
            return card;
        });
        when(cryptoService.encryptAESGCM(anyString())).thenAnswer(i -> "enc:" + i.getArgument(0));
        service = new BankingService(accountRepo, cardRepo, userRepo, cryptoService);
    }

    @Test
    @SuppressWarnings("unchecked")
    void opensAnEmptyAccountWithAStandardIbanAndAnEncryptedCard()
    {
        Map<String, Object> result = service.createAccountAndCard(5L, "RON", "RO");

        ArgumentCaptor<AccountJpaEntity> account = ArgumentCaptor.forClass(AccountJpaEntity.class);
        verify(accountRepo).save(account.capture());
        assertTrue(AccountNumbers.isValidIban(account.getValue().getIBAN()));
        assertEquals("RON", account.getValue().getMoneda());
        assertEquals(0, BigDecimal.ZERO.compareTo(account.getValue().getSold()));

        ArgumentCaptor<CardJpaEntity> card = ArgumentCaptor.forClass(CardJpaEntity.class);
        verify(cardRepo).save(card.capture());
        String pan = card.getValue().getNumarCard().substring("enc:".length());
        assertTrue(AccountNumbers.isLuhnValid(pan));
        assertEquals("Popescu Ion", card.getValue().getDetinator());
        assertTrue(card.getValue().getToken().startsWith("tok_"));

        var cardInfo = (Map<String, Object>) result.get("card");
        assertEquals(pan.substring(12), cardInfo.get("last4"));
        assertFalse(cardInfo.toString().contains(pan), "full card number must not be returned");
    }

    @Test
    void neverGeneratesOrEncryptsACvv()
    {
        service.createAccountAndCard(5L, "EUR", "RO");

        // Only the card number and the expiry date are encrypted for storage.
        ArgumentCaptor<String> encrypted = ArgumentCaptor.forClass(String.class);
        verify(cryptoService, times(2)).encryptAESGCM(encrypted.capture());
        assertTrue(encrypted.getAllValues().get(0).matches("\\d{16}"));
        assertTrue(encrypted.getAllValues().get(1).matches("\\d{2}/\\d{2}"));
        assertTrue(Arrays.stream(CardJpaEntity.class.getDeclaredFields())
                .noneMatch(f -> f.getName().toLowerCase().contains("cvv")), "card entity must not map a CVV");
    }

    @Test
    void retriesOnAnIbanCollisionThenGivesUpOnOtherErrors()
    {
        doThrow(new RuntimeException("duplicate key value violates unique constraint"))
                .doAnswer(i -> withId(i.getArgument(0), 41L))
                .when(accountRepo).save(any());
        assertNotNull(service.createAccountAndCardWithRetry(5L, "RON", "RO"));
        verify(accountRepo, times(2)).save(any());

        doThrow(new RuntimeException("connection refused")).when(accountRepo).save(any());
        assertThrows(RuntimeException.class, () -> service.createAccountAndCardWithRetry(5L, "RON", "RO"));
    }

    private static AccountJpaEntity withId(AccountJpaEntity account, long id)
    {
        account.setId(id);
        return account;
    }
}
