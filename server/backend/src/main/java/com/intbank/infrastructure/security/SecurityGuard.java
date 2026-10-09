package com.intbank.infrastructure.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component("securityGuard")
public class SecurityGuard
{

    public boolean isSelfOrAdmin(Long targetUserId)
    {
        if (targetUserId == null)
        {
            return false;
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthenticatedClient client))
        {
            return false;
        }
        if (client.hasRole("ROLE_ADMIN"))
        {
            return true;
        }
        return targetUserId.equals(client.userId());
    }

    public boolean isAdmin()
    {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthenticatedClient client))
        {
            return false;
        }
        return client.hasRole("ROLE_ADMIN");
    }

    /** True for the onboarding token issued after the SMS code (no full session yet). */
    public boolean isOnboardingOnly()
    {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null && auth.getPrincipal() instanceof AuthenticatedClient client
                && client.hasRole(com.intbank.service.PreAuthTokenService.ROLE)
                && !client.hasRole("ROLE_USER") && !client.hasRole("ROLE_ADMIN");
    }

    public Long getAuthenticatedUserId()
    {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof AuthenticatedClient client)
        {
            return client.userId();
        }
        return null;
    }
}
