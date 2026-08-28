package com.intbank.infrastructure.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public class ClientTokenFilter extends OncePerRequestFilter
{

    private final SecretKey jwtSecret;

    public ClientTokenFilter(String jwtSecretRaw)
    {
        this.jwtSecret = Keys.hmacShaKeyFor(jwtSecretRaw.getBytes(StandardCharsets.UTF_8));
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request)
    {
        String path = request.getRequestURI();
        return path.equals("/health")
                || path.startsWith("/actuator/health")
                || path.startsWith("/auth/")
                || path.equals("/login")
                || path.equals("/register")
                || path.startsWith("/2fa/")
                || path.equals("/error");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException
    {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer "))
        {
            chain.doFilter(request, response);
            return;
        }

        try
        {
            String token = authHeader.substring(7);
            Claims claims = Jwts.parser().verifyWith(jwtSecret).build()
                    .parseSignedClaims(token).getPayload();

            String deviceId = claims.getSubject();
            Long userId = claims.get("uid", Long.class);
            List<String> roles = claims.get("roles", List.class);
            if (roles == null || roles.isEmpty())
            {
                roles = new ArrayList<>(List.of("ROLE_USER"));
            }

            List<SimpleGrantedAuthority> authorities = roles.stream()
                    .map(SimpleGrantedAuthority::new)
                    .toList();

            AuthenticatedClient principal = new AuthenticatedClient(deviceId, userId, roles);
            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(principal, null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }
        catch (Exception e)
        {
            // Invalid token: leave SecurityContext empty so the authorization rules reject the request.
            SecurityContextHolder.clearContext();
        }

        chain.doFilter(request, response);
    }
}
