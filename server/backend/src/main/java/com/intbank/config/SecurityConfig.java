package com.intbank.config;

import com.intbank.infrastructure.security.ClientTokenFilter;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig
{

    static final String[] ONBOARDING_READS = {"/users/*/has-tos", "/users/*/has-approved", "/users/*/has-pin", "/ws/approval"};
    static final String[] ONBOARDING_WRITES = {"/users/*/accept-tos", "/users/*/set-pin"};
    private static final String[] CUSTOMER_OR_ONBOARDING = {"ROLE_USER", "ROLE_ADMIN", com.intbank.service.PreAuthTokenService.ROLE};

    private final String jwtSecret;
    private final com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider;
    private final com.intbank.service.TokenBlacklistService tokenBlacklistService;

    public SecurityConfig(@Value("${jwt.secret}") String jwtSecret,
                          com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider,
                          com.intbank.service.TokenBlacklistService tokenBlacklistService)
    {
        this.jwtSecret = jwtSecret;
        this.rsaKeyProvider = rsaKeyProvider;
        this.tokenBlacklistService = tokenBlacklistService;
    }

    @Bean
    public org.springframework.security.crypto.password.PasswordEncoder passwordEncoder()
    {
        return new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception
    {
        ClientTokenFilter clientTokenFilter = new ClientTokenFilter(jwtSecret, rsaKeyProvider, tokenBlacklistService);
        com.intbank.infrastructure.security.TokenBucketRateLimiter rateLimiter = new com.intbank.infrastructure.security.TokenBucketRateLimiter();
        com.intbank.infrastructure.security.RateLimitingFilter rateLimitingFilter = new com.intbank.infrastructure.security.RateLimitingFilter(rateLimiter);

        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .headers(headers -> headers
                .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000))
                .frameOptions(frame -> frame.deny())
                .contentTypeOptions(content -> {})
                .cacheControl(cache -> {})
                .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'; script-src 'self'; frame-ancestors 'none';"))
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/health", "/actuator/health/**", "/error").permitAll()
                .requestMatchers("/actuator/prometheus", "/actuator/metrics", "/actuator/info").permitAll()
                .requestMatchers("/auth/**", "/auth-session/**", "/login", "/register", "/2fa/**", "/.well-known/**").permitAll()
                // Only the read-only rate endpoints are public; the exchange itself needs a user token.
                .requestMatchers("/currency/api/v1/exchange-rates", "/currency/api/v1/convert").permitAll()
                .requestMatchers("/admin/**").hasAuthority("ROLE_ADMIN")
                // Onboarding steps a customer can take right after the SMS code, before choosing a PIN.
                .requestMatchers(org.springframework.http.HttpMethod.GET, ONBOARDING_READS).hasAnyAuthority(CUSTOMER_OR_ONBOARDING)
                .requestMatchers(ONBOARDING_WRITES).hasAnyAuthority(CUSTOMER_OR_ONBOARDING)
                // Everything else needs a full session (phone + PIN). Device tokens (ROLE_DEVICE) open nothing.
                .anyRequest().hasAnyAuthority("ROLE_USER", "ROLE_ADMIN")
            )
            .exceptionHandling(ex -> ex.authenticationEntryPoint((request, response, authException) ->
            {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                Map<String, Object> body = new LinkedHashMap<>();
                body.put("status", HttpServletResponse.SC_UNAUTHORIZED);
                body.put("error", "Unauthorized");
                response.getWriter().write(new ObjectMapper().writeValueAsString(body));
            }))
            .addFilterBefore(clientTokenFilter, UsernamePasswordAuthenticationFilter.class)
            .addFilterAfter(new com.intbank.infrastructure.security.UserScopeAuthorizationFilter(), ClientTokenFilter.class)
            .addFilterBefore(rateLimitingFilter, ClientTokenFilter.class);

        return http.build();
    }
}
