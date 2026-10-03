package com.intbank.infrastructure.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;

/**
 * Spring Security filter enforcing adaptive token bucket rate limiting.
 * Protects authentication, 2FA, PIN, and transfer endpoints against brute force,
 * credential stuffing, and user enumeration attacks.
 */
public class RateLimitingFilter extends OncePerRequestFilter
{
    private final TokenBucketRateLimiter rateLimiter;
    private final ObjectMapper objectMapper;

    // Strict policy for auth, login, and registration endpoints (10 burst, 1 refill/sec)
    private static final TokenBucketRateLimiter.RateLimitPolicy AUTH_POLICY =
            new TokenBucketRateLimiter.RateLimitPolicy(10, 1, 5);

    // Strictest policy for SMS 2FA and OTP to avoid financial/SMS inflation (5 burst, 1 refill/sec)
    private static final TokenBucketRateLimiter.RateLimitPolicy TWO_FA_POLICY =
            new TokenBucketRateLimiter.RateLimitPolicy(5, 1, 2);

    // Strict policy for PIN verification to prevent brute-forcing 4-digit PINs (5 burst, 1 refill/sec)
    private static final TokenBucketRateLimiter.RateLimitPolicy PIN_POLICY =
            new TokenBucketRateLimiter.RateLimitPolicy(5, 1, 2);

    // Policy for financial transfer dispatching (20 burst, 2 refill/sec)
    private static final TokenBucketRateLimiter.RateLimitPolicy TRANSFER_POLICY =
            new TokenBucketRateLimiter.RateLimitPolicy(20, 2, 5);

    // General policy for standard authenticated endpoints (100 capacity, 20 refill/sec)
    private static final TokenBucketRateLimiter.RateLimitPolicy GENERAL_POLICY =
            new TokenBucketRateLimiter.RateLimitPolicy(100, 20, 50);

    public RateLimitingFilter(TokenBucketRateLimiter rateLimiter, ObjectMapper objectMapper)
    {
        this.rateLimiter = rateLimiter;
        this.objectMapper = objectMapper;
    }

    public RateLimitingFilter(TokenBucketRateLimiter rateLimiter)
    {
        this(rateLimiter, new ObjectMapper());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException
    {
        String path = request.getRequestURI();

        // Bypass health checks and metrics
        if (path.startsWith("/health") || path.startsWith("/actuator") || path.equals("/error"))
        {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = extractClientIp(request);
        TokenBucketRateLimiter.RateLimitPolicy policy;
        String bucketKey;

        if (path.contains("/verify-pin"))
        {
            policy = PIN_POLICY;
            bucketKey = "pin:" + clientIp;
        }
        else if (path.startsWith("/2fa"))
        {
            policy = TWO_FA_POLICY;
            bucketKey = "2fa:" + clientIp;
        }
        else if (path.startsWith("/login") || path.startsWith("/register") || path.startsWith("/auth"))
        {
            policy = AUTH_POLICY;
            bucketKey = "auth:" + clientIp;
        }
        else if (path.contains("/transfer"))
        {
            policy = TRANSFER_POLICY;
            bucketKey = "transfer:" + clientIp;
        }
        else
        {
            policy = GENERAL_POLICY;
            bucketKey = "general:" + clientIp;
        }

        var result = rateLimiter.tryConsume(bucketKey, policy);

        if (!result.isAllowed())
        {
            long retryAfter = Math.max(1, result.retryAfterSeconds());
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setHeader("Retry-After", String.valueOf(retryAfter));

            Map<String, Object> body = Map.of(
                    "status", HttpStatus.TOO_MANY_REQUESTS.value(),
                    "error", "Too Many Requests",
                    "message", "Prea multe cereri. Încearcă din nou în " + retryAfter + " secunde.",
                    "retryAfterSeconds", retryAfter
            );
            response.getWriter().write(objectMapper.writeValueAsString(body));
            return;
        }

        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.availableTokens()));
        filterChain.doFilter(request, response);
    }

    private String extractClientIp(HttpServletRequest request)
    {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank())
        {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr() : "127.0.0.1";
    }
}
