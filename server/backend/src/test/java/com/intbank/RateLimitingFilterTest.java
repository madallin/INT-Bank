package com.intbank;

import com.intbank.infrastructure.security.RateLimitingFilter;
import com.intbank.infrastructure.security.TokenBucketRateLimiter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;

public class RateLimitingFilterTest
{
    private RateLimitingFilter filter;
    private TokenBucketRateLimiter rateLimiter;

    @BeforeEach
    void setUp()
    {
        rateLimiter = new TokenBucketRateLimiter();
        filter = new RateLimitingFilter(rateLimiter);
    }

    @Test
    void doFilter_WhenWithinLimit_PassesThrough() throws ServletException, IOException
    {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/login");
        request.setRemoteAddr("192.168.1.100");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertNotNull(response.getHeader("X-RateLimit-Remaining"));
    }

    @Test
    void doFilter_WhenExceedingLimit_Returns429TooManyRequests() throws ServletException, IOException
    {
        String clientIp = "192.168.1.101";

        // Auth policy has capacity 10 + burst 5 = 15 total tokens initially
        for (int i = 0; i < 15; i++)
        {
            MockHttpServletRequest req = new MockHttpServletRequest("POST", "/login");
            req.setRemoteAddr(clientIp);
            MockHttpServletResponse resp = new MockHttpServletResponse();
            filter.doFilter(req, resp, new MockFilterChain());
            assertEquals(200, resp.getStatus(), "Request " + i + " should succeed");
        }

        // 16th request should hit 429
        MockHttpServletRequest blockedReq = new MockHttpServletRequest("POST", "/login");
        blockedReq.setRemoteAddr(clientIp);
        MockHttpServletResponse blockedResp = new MockHttpServletResponse();
        filter.doFilter(blockedReq, blockedResp, new MockFilterChain());

        assertEquals(429, blockedResp.getStatus());
        assertNotNull(blockedResp.getHeader("Retry-After"));
        assertTrue(blockedResp.getContentAsString().contains("Too Many Requests"));
    }

    @Test
    void doFilter_HealthEndpoint_BypassesRateLimiting() throws ServletException, IOException
    {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/health");
        request.setRemoteAddr("10.0.0.1");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertNull(response.getHeader("X-RateLimit-Remaining"));
    }
}
