package com.intbank.infrastructure.security;

import com.intbank.config.SecurityConfig;
import com.intbank.infrastructure.persistence.repository.BeneficiaryJpaRepository;
import com.intbank.infrastructure.rest.BeneficiaryController;
import com.intbank.infrastructure.rest.CurrencyController;
import com.intbank.service.AuditLogService;
import com.intbank.service.CurrencyExchangeService;
import com.intbank.service.CurrencyService;
import com.intbank.service.ExchangeRateCacheService;
import com.intbank.service.NotificationService;
import com.intbank.service.TokenBlacklistService;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.math.BigDecimal;
import java.util.Date;
import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Runs requests through the real {@link SecurityConfig} filter chain (token parsing, path
 * rules and {@link UserScopeAuthorizationFilter}) with RS256 tokens shaped like the ones
 * the backend issues. Audit findings F2 and F3.
 */
@WebMvcTest(controllers = {CurrencyController.class, BeneficiaryController.class})
@Import({SecurityConfig.class, SecurityGuard.class, RsaKeyProvider.class})
@TestPropertySource(properties = "jwt.secret=test-secret-test-secret-test-secret-0123456789")
class SecurityChainWiringTest
{

    private static final String EXCHANGE = "/currency/api/v1/users/7/exchange/internal";
    private static final String EXCHANGE_BODY = "{\"quoteId\":\"fxq-1\"}";

    @Autowired private MockMvc mvc;
    @Autowired private RsaKeyProvider rsaKeyProvider;

    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private CurrencyService currencyService;
    @MockBean private ExchangeRateCacheService rateCache;
    @MockBean private AuditLogService auditLogService;
    @MockBean private NotificationService notificationService;
    @MockBean private CurrencyExchangeService exchangeService;
    @MockBean private BeneficiaryJpaRepository beneficiaryRepo;

    @Test
    void exchangeRequiresAToken() throws Exception
    {
        mvc.perform(exchange(null)).andExpect(status().isUnauthorized());
        verifyNoInteractions(exchangeService);
    }

    @Test
    void exchangeRejectsADeviceTokenWithoutUser() throws Exception
    {
        mvc.perform(exchange(token(null, "ROLE_USER"))).andExpect(status().isForbidden());
        verifyNoInteractions(exchangeService);
    }

    @Test
    void exchangeRejectsAnotherCustomersToken() throws Exception
    {
        mvc.perform(exchange(token(8L, "ROLE_USER"))).andExpect(status().isForbidden());
        verifyNoInteractions(exchangeService);
    }

    @Test
    void exchangeRunsForTheOwner() throws Exception
    {
        when(exchangeService.execute(7L, "fxq-1")).thenReturn(new CurrencyExchangeService.Execution(new CurrencyExchangeService.ExchangeResult(
                "FX-1", new BigDecimal("100.00"), "RON", new BigDecimal("20.10"), "EUR",
                new BigDecimal("0.201"), new BigDecimal("900.00"), new BigDecimal("20.10")), false));

        mvc.perform(exchange(token(7L, "ROLE_USER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.destinationAmount").value(20.10));
        verify(exchangeService).execute(7L, "fxq-1");
    }

    @Test
    void ratesStayPublic() throws Exception
    {
        mvc.perform(get("/currency/api/v1/exchange-rates")).andExpect(status().isOk());
    }

    @Test
    void beneficiariesOfAnotherCustomerAreForbidden() throws Exception
    {
        mvc.perform(get("/users/7/beneficiaries").header("Authorization", "Bearer " + token(8L, "ROLE_USER")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/users/7/beneficiaries").header("Authorization", "Bearer " + token(null, "ROLE_USER")))
                .andExpect(status().isForbidden());
        verifyNoInteractions(beneficiaryRepo);

        mvc.perform(get("/users/7/beneficiaries").header("Authorization", "Bearer " + token(7L, "ROLE_USER")))
                .andExpect(status().isOk());
        verify(beneficiaryRepo).findByUserIdOrderByNameAsc(7L);
    }

    private MockHttpServletRequestBuilder exchange(String token)
    {
        var request = post(EXCHANGE).contentType(MediaType.APPLICATION_JSON).content(EXCHANGE_BODY);
        return token == null ? request : request.header("Authorization", "Bearer " + token);
    }

    private String token(Long uid, String role)
    {
        var builder = Jwts.builder()
                .subject(uid == null ? "device-abc" : "+40700000000")
                .claim("roles", List.of(role))
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(rsaKeyProvider.getPrivateKey());
        if (uid != null)
        {
            builder.claim("uid", uid);
        }
        return builder.compact();
    }
}
