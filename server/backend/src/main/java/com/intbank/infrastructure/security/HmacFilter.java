package com.intbank.infrastructure.security;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.util.HexFormat;

@Component
@Order(1)
public class HmacFilter implements Filter
{

    private static final Logger log = LoggerFactory.getLogger(HmacFilter.class);
    private final boolean enabled;
    private final SecretKeySpec hmacKey;

    public HmacFilter(
        @Value("${hmac.enabled:true}") boolean enabled,
        @Value("${encryption.hmac-key-hex:}") String hmacKeyHex
    )
    {
        this.enabled = enabled;
        if (hmacKeyHex != null && !hmacKeyHex.isEmpty()) {
            this.hmacKey = new SecretKeySpec(HexFormat.of().parseHex(hmacKeyHex), "HmacSHA512");
        } else {
            this.hmacKey = null;
        }
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException
    {
        HttpServletRequest httpReq = (HttpServletRequest) request;
        HttpServletResponse httpRes = (HttpServletResponse) response;

        if (!enabled || hmacKey == null || isExcluded(httpReq.getRequestURI())) {
            chain.doFilter(request, response);
            return;
        }

        String signature = httpReq.getHeader("X-Signature");
        if (signature == null || signature.isEmpty()) {
            httpRes.setStatus(401);
            httpRes.getWriter().write("{\"error\":\"Missing HMAC signature\"}");
            return;
        }

        // Basic HMAC validation — full implementation needs request body hashing
        try {
            Mac mac = Mac.getInstance("HmacSHA512");
            mac.init(hmacKey);
            String expectedSignature = HexFormat.of().formatHex(
                    mac.doFinal((httpReq.getMethod() + httpReq.getRequestURI()).getBytes()));
            if (!signature.equals(expectedSignature)) {
                httpRes.setStatus(401);
                httpRes.getWriter().write("{\"error\":\"Invalid HMAC signature\"}");
                return;
            }
        } catch (Exception e) {
            log.error("HMAC validation error", e);
            httpRes.setStatus(500);
            return;
        }

        chain.doFilter(request, response);
    }

    private boolean isExcluded(String uri)
    {
        return uri.equals("/health") || uri.startsWith("/auth/");
    }
}