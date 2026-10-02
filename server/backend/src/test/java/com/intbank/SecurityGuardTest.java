package com.intbank;

import com.intbank.infrastructure.security.AuthenticatedClient;
import com.intbank.infrastructure.security.SecurityGuard;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class SecurityGuardTest
{

    private SecurityGuard securityGuard;

    @BeforeEach
    void setUp()
    {
        securityGuard = new SecurityGuard();
    }

    @AfterEach
    void tearDown()
    {
        SecurityContextHolder.clearContext();
    }

    @Test
    void isSelfOrAdmin_WhenAuthenticatedAsTargetUser_ReturnsTrue()
    {
        AuthenticatedClient client = new AuthenticatedClient("dev-1", 42L, List.of("ROLE_USER"));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(client, null, List.of(new SimpleGrantedAuthority("ROLE_USER")))
        );

        assertTrue(securityGuard.isSelfOrAdmin(42L));
    }

    @Test
    void isSelfOrAdmin_WhenAccessingOtherUser_ReturnsFalse()
    {
        AuthenticatedClient client = new AuthenticatedClient("dev-1", 42L, List.of("ROLE_USER"));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(client, null, List.of(new SimpleGrantedAuthority("ROLE_USER")))
        );

        assertFalse(securityGuard.isSelfOrAdmin(99L));
    }

    @Test
    void isSelfOrAdmin_WhenAdminAccessesAnyUser_ReturnsTrue()
    {
        AuthenticatedClient admin = new AuthenticatedClient("admin-dev", 1L, List.of("ROLE_ADMIN"));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(admin, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")))
        );

        assertTrue(securityGuard.isSelfOrAdmin(99L));
        assertTrue(securityGuard.isAdmin());
    }

    @Test
    void isSelfOrAdmin_WhenUnauthenticated_ReturnsFalse()
    {
        SecurityContextHolder.clearContext();
        assertFalse(securityGuard.isSelfOrAdmin(42L));
        assertFalse(securityGuard.isAdmin());
    }
}
