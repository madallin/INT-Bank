package com.intbank.infrastructure.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
@Order(2)
public class ClientTokenFilter implements Filter
{

    private final SecretKey jwtSecret;

    public ClientTokenFilter(@Value("${jwt.secret}") String jwtSecretRaw)
    {
        this.jwtSecret = Keys.hmacShaKeyFor(jwtSecretRaw.getBytes(StandardCharsets.UTF_8));
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException
    {
        HttpServletRequest httpReq = (HttpServletRequest) request;
        HttpServletResponse httpRes = (HttpServletResponse) response;

        String path = httpReq.getRequestURI();
        if (isExcluded(path)) {
            chain.doFilter(request, response);
            return;
        }

        String authHeader = httpReq.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            chain.doFilter(request, response);
            return;
        }

        try {
            String token = authHeader.substring(7);
            Claims claims = Jwts.parser().verifyWith(jwtSecret).build()
                    .parseSignedClaims(token).getPayload();
            request.setAttribute("deviceId", claims.getSubject());
        } catch (Exception e) {
            // Token invalid — continue without authentication
        }

        chain.doFilter(request, response);
    }

    private boolean isExcluded(String uri)
    {
        return uri.equals("/health") || uri.startsWith("/auth/");
    }
}