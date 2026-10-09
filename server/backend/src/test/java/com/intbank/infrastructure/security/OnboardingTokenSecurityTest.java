package com.intbank.infrastructure.security;

import com.intbank.config.SecurityConfig;
import com.intbank.core.port.in.TransferUseCase;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.rest.AccountController;
import com.intbank.infrastructure.rest.TransactionController;
import com.intbank.infrastructure.rest.UserController;
import com.intbank.service.AuditLogService;
import com.intbank.service.BankingService;
import com.intbank.service.NotificationService;
import com.intbank.service.PinVerificationService;
import com.intbank.service.PreAuthTokenService;
import com.intbank.service.StrongCustomerAuthService;
import com.intbank.service.TokenBlacklistService;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.Date;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * What each kind of token can reach, through the real filter chain:
 * device token (no customer) - nothing; onboarding token (after the SMS code) - only the
 * onboarding steps of its own customer; full session (phone + PIN) - the customer's banking.
 */
@WebMvcTest(controllers = {UserController.class, AccountController.class, TransactionController.class})
@Import({SecurityConfig.class, SecurityGuard.class, RsaKeyProvider.class})
@TestPropertySource(properties = "jwt.secret=test-secret-test-secret-test-secret-0123456789")
class OnboardingTokenSecurityTest
{

    @Autowired private MockMvc mvc;
    @Autowired private RsaKeyProvider keys;

    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private UserJpaRepository userRepo;
    @MockBean private BankingService bankingService;
    @MockBean private PinVerificationService pinVerification;
    @MockBean private AccountJpaRepository accountRepo;
    @MockBean private AuditLogService auditLogService;
    @MockBean private NotificationService notificationService;
    @MockBean private TransferUseCase transferUseCase;
    @MockBean private TransferJpaRepository transferRepo;
    @MockBean private StrongCustomerAuthService strongCustomerAuth;

    private UserJpaEntity customer;

    @BeforeEach
    void setUp()
    {
        customer = new UserJpaEntity();
        customer.setId(7L);
        when(userRepo.findById(7L)).thenReturn(Optional.of(customer));
        when(accountRepo.findByUser_Id(7L)).thenReturn(List.of());
    }

    @Test
    void onboardingTokenReachesOnlyItsOwnOnboardingSteps() throws Exception
    {
        String onboarding = token(7L, PreAuthTokenService.ROLE);

        expect(get("/users/7/has-pin"), onboarding, status().isOk());
        expect(get("/users/7/has-tos"), onboarding, status().isOk());
        expect(get("/users/7/has-approved"), onboarding, status().isOk());
        expect(put("/users/7/accept-tos"), onboarding, status().isOk());

        // Not banking, and not another customer.
        expect(get("/users/7/accounts"), onboarding, status().isForbidden());
        expect(get("/users/7"), onboarding, status().isForbidden());
        expect(post("/users/7/transfer").contentType(MediaType.APPLICATION_JSON).content("{}"), onboarding, status().isForbidden());
        expect(post("/users/7/verify-pin").contentType(MediaType.APPLICATION_JSON).content("{\"pin\":\"1\"}"), onboarding, status().isForbidden());
        expect(get("/users/8/has-pin"), onboarding, status().isForbidden());
        verifyNoInteractions(transferUseCase);
    }

    @Test
    void onboardingTokenCanChooseTheFirstPinButNeverReplaceOne() throws Exception
    {
        String onboarding = token(7L, PreAuthTokenService.ROLE);
        String body = "{\"codPin\":\"246802\"}";

        expect(put("/users/7/set-pin").contentType(MediaType.APPLICATION_JSON).content(body), onboarding, status().isOk());

        customer.setCodPin("$2a$hash");
        mvc.perform(withToken(put("/users/7/set-pin").contentType(MediaType.APPLICATION_JSON).content(body), onboarding))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("PIN_ALREADY_SET"));
    }

    @Test
    void replacingAPinNeedsTheCurrentOneEvenWithAFullSession() throws Exception
    {
        customer.setCodPin("$2a$hash");
        when(pinVerification.verify(eq(7L), isNull()))
                .thenReturn(new PinVerificationService.Result(PinVerificationService.Outcome.WRONG_PIN, 2, 0));

        mvc.perform(withToken(put("/users/7/set-pin").contentType(MediaType.APPLICATION_JSON).content("{\"codPin\":\"111111\"}"),
                        token(7L, "ROLE_USER")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("SCA_PIN_INVALID"));
    }

    @Test
    void theApprovalSocketNeedsACustomerToken() throws Exception
    {
        mvc.perform(get("/ws/approval")).andExpect(status().isUnauthorized());
        expect(get("/ws/approval"), token(null, "ROLE_DEVICE"), status().isForbidden());
        // With an onboarding token the request passes security (no socket handler in this slice).
        mvc.perform(withToken(get("/ws/approval"), token(7L, PreAuthTokenService.ROLE)))
                .andExpect(result -> org.junit.jupiter.api.Assertions.assertFalse(
                        result.getResponse().getStatus() == 401 || result.getResponse().getStatus() == 403));
    }

    @Test
    void deviceTokensAndRolelessTokensOpenNothing() throws Exception
    {
        expect(get("/users/7/has-pin"), token(null, "ROLE_DEVICE"), status().isForbidden());
        expect(get("/users/7/accounts"), token(null, "ROLE_DEVICE"), status().isForbidden());
        expect(get("/users/7/accounts"), tokenWithoutRoles(7L), status().isForbidden());
    }

    @Test
    void aFullSessionReachesTheCustomersBanking() throws Exception
    {
        expect(get("/users/7/accounts"), token(7L, "ROLE_USER"), status().isOk());
        expect(get("/users/7/has-pin"), token(7L, "ROLE_USER"), status().isOk());
    }

    private void expect(MockHttpServletRequestBuilder request, String token, ResultMatcher expected) throws Exception
    {
        mvc.perform(withToken(request, token)).andExpect(expected);
    }

    private static MockHttpServletRequestBuilder withToken(MockHttpServletRequestBuilder request, String token)
    {
        return request.header("Authorization", "Bearer " + token);
    }

    private String token(Long uid, String role)
    {
        var builder = Jwts.builder()
                .subject(uid == null ? "device-abc" : "+40712345678")
                .claim("roles", List.of(role))
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(keys.getPrivateKey());
        if (uid != null) builder.claim("uid", uid);
        return builder.compact();
    }

    private String tokenWithoutRoles(Long uid)
    {
        return Jwts.builder().subject("x").claim("uid", uid)
                .expiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(keys.getPrivateKey()).compact();
    }
}
