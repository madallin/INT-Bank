package com.intbank.infrastructure.rest;

import com.intbank.core.domain.vo.AccountNumbers;
import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.security.AuthenticatedClient;
import com.intbank.infrastructure.security.SecurityGuard;
import com.intbank.service.AuditLogService;
import com.intbank.service.NotificationService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Opening currency accounts and reading account details. */
class AccountControllerTest
{

    private static final long USER = 7L;

    private AccountJpaRepository accountRepo;
    private AccountController controller;

    @BeforeEach
    void setUp()
    {
        accountRepo = mock(AccountJpaRepository.class);
        UserJpaRepository userRepo = mock(UserJpaRepository.class);
        UserJpaEntity user = new UserJpaEntity();
        user.setId(USER);
        when(userRepo.findById(USER)).thenReturn(Optional.of(user));
        when(accountRepo.save(any())).thenAnswer(i -> {
            AccountJpaEntity a = i.getArgument(0);
            a.setId(55L);
            return a;
        });
        controller = new AccountController(accountRepo, userRepo, mock(AuditLogService.class),
                mock(NotificationService.class), new SecurityGuard());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new AuthenticatedClient("phone", USER, List.of("ROLE_USER")), null, List.of()));
    }

    @AfterEach
    void clear()
    {
        SecurityContextHolder.clearContext();
    }

    @Test
    @SuppressWarnings("unchecked")
    void opensAnEmptyAccountWithAStandardIbanInTheRequestedCurrency()
    {
        var response = controller.createAccount(USER, Map.of("currency", "eur"));

        assertEquals(201, response.getStatusCode().value());
        var account = (Map<String, Object>) response.getBody().get("account");
        String iban = (String) account.get("iban");
        assertTrue(AccountNumbers.isValidIban(iban), iban);
        assertEquals("EUR", iban.substring(8, 11));
        assertEquals("EUR", account.get("moneda"));
        assertEquals(0, BigDecimal.ZERO.compareTo((BigDecimal) account.get("sold")));
    }

    @Test
    void rejectsUnsupportedCurrenciesAndOtherCustomers()
    {
        assertEquals(400, controller.createAccount(USER, Map.of("currency", "JPY")).getStatusCode().value());
        assertEquals(403, controller.createAccount(8L, Map.of("currency", "EUR")).getStatusCode().value());
        verify(accountRepo, never()).save(any());
    }

    @Test
    void anotherCustomersAccountIsNotFoundEvenByItsId()
    {
        AccountJpaEntity foreign = new AccountJpaEntity();
        foreign.setId(9L);
        UserJpaEntity other = new UserJpaEntity();
        other.setId(8L);
        foreign.setUser(other);
        when(accountRepo.findById(9L)).thenReturn(Optional.of(foreign));

        assertEquals(404, controller.getAccount(USER, 9L).getStatusCode().value());
    }
}
