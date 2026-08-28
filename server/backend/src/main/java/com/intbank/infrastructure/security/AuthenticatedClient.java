package com.intbank.infrastructure.security;

import java.util.List;

public class AuthenticatedClient
{

    private final String deviceId;
    private final Long userId;
    private final List<String> roles;

    public AuthenticatedClient(String deviceId, Long userId, List<String> roles)
    {
        this.deviceId = deviceId;
        this.userId = userId;
        this.roles = roles != null ? roles : List.of();
    }

    public String deviceId()
    {
        return deviceId;
    }

    public Long userId()
    {
        return userId;
    }

    public List<String> roles()
    {
        return roles;
    }

    public boolean hasRole(String role)
    {
        return roles.contains(role);
    }
}
