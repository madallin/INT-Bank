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

@Configuration
@EnableWebSecurity
public class SecurityConfig
{

    private final String jwtSecret;
    private final com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider;

    public SecurityConfig(@Value("${jwt.secret}") String jwtSecret,
                          com.intbank.infrastructure.security.RsaKeyProvider rsaKeyProvider)
    {
        this.jwtSecret = jwtSecret;
        this.rsaKeyProvider = rsaKeyProvider;
    }

    @Bean
    public org.springframework.security.crypto.password.PasswordEncoder passwordEncoder()
    {
        return new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception
    {
        ClientTokenFilter clientTokenFilter = new ClientTokenFilter(jwtSecret, rsaKeyProvider);

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
                .requestMatchers("/auth/**", "/auth-session/**", "/login", "/register", "/2fa/**", "/currency/**", "/ws/**", "/.well-known/**").permitAll()
                .requestMatchers("/admin/**").hasAuthority("ROLE_ADMIN")
                .requestMatchers("/transfers/**", "/users/**").authenticated()
                .anyRequest().authenticated()
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
            .addFilterBefore(clientTokenFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
