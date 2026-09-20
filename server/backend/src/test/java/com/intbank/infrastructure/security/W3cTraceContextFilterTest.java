package com.intbank.infrastructure.security;

import com.intbank.infrastructure.security.W3cTraceContextFilter.TraceContext;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class W3cTraceContextFilterTest
{
    private static final String CANONICAL_TRACEPARENT = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";
    private static final String INBOUND_TRACE_ID = "4bf92f3577b34da6a3ce929d0e0e4736";
    private static final String INBOUND_SPAN_ID = "00f067aa0ba902b7";
    private static final String ZERO_TRACE_ID = "00000000000000000000000000000000";
    private static final String ZERO_SPAN_ID = "0000000000000000";

    private final W3cTraceContextFilter filter = new W3cTraceContextFilter();

    @AfterEach
    void clearMdc()
    {
        MDC.clear();
    }

    private MockFilterChain captureChain(AtomicReference<String> traceId, AtomicReference<TraceContext> context)
    {
        HttpServlet captureServlet = new HttpServlet()
        {
            @Override
            protected void service(HttpServletRequest servletRequest, HttpServletResponse servletResponse)
            {
                traceId.set(MDC.get(W3cTraceContextFilter.MDC_TRACE_ID_KEY));
                context.set((TraceContext) servletRequest.getAttribute(W3cTraceContextFilter.TRACE_CONTEXT_ATTRIBUTE));
            }
        };
        return new MockFilterChain(captureServlet);
    }

    @Test
    @DisplayName("Parses the canonical W3C traceparent example")
    void parsesCanonicalTraceparent()
    {
        Optional<TraceContext> parsed = W3cTraceContextFilter.parseTraceparent(CANONICAL_TRACEPARENT);

        assertTrue(parsed.isPresent());
        TraceContext context = parsed.get();
        assertEquals(INBOUND_TRACE_ID, context.traceId());
        assertEquals(INBOUND_SPAN_ID, context.parentSpanId());
        assertTrue(context.isSampled());
        assertNotNull(context.spanId());
        assertEquals(16, context.spanId().length());
        assertTrue(context.spanId().matches("[0-9a-f]{16}"));
    }

    @Test
    @DisplayName("Rejects malformed traceparent headers")
    void rejectsMalformedTraceparent()
    {
        String zeroTraceId = "00-" + ZERO_TRACE_ID + "-" + INBOUND_SPAN_ID + "-01";
        String zeroSpanId = "00-" + INBOUND_TRACE_ID + "-" + ZERO_SPAN_ID + "-01";
        String uppercaseTraceId = "00-4BF92F3577B34DA6A3CE929D0E0E4736-" + INBOUND_SPAN_ID + "-01";
        String uppercaseSpanId = "00-" + INBOUND_TRACE_ID + "-00F067AA0BA902B7-01";
        String unsupportedVersion = "ff-" + INBOUND_TRACE_ID + "-" + INBOUND_SPAN_ID + "-01";
        String nonHexTraceId = "00-4bf92g3577b34da6a3ce929d0e0e4736-" + INBOUND_SPAN_ID + "-01";
        String nonHexSpanId = "00-" + INBOUND_TRACE_ID + "-00f067aa0ba902zz-01";
        String nonHexFlags = "00-" + INBOUND_TRACE_ID + "-" + INBOUND_SPAN_ID + "-zz";
        String tooShort = "00-" + INBOUND_TRACE_ID + "-" + INBOUND_SPAN_ID;
        String tooLong = CANONICAL_TRACEPARENT + "0";

        List<String> malformed = List.of(
                zeroTraceId,
                zeroSpanId,
                uppercaseTraceId,
                uppercaseSpanId,
                unsupportedVersion,
                nonHexTraceId,
                nonHexSpanId,
                nonHexFlags,
                tooShort,
                tooLong,
                "",
                "   ");

        for (String candidate : malformed)
        {
            assertTrue(W3cTraceContextFilter.parseTraceparent(candidate).isEmpty(), candidate);
        }
        assertTrue(W3cTraceContextFilter.parseTraceparent(null).isEmpty());
    }

    @Test
    @DisplayName("Generates a compliant trace context and 55 character traceparent")
    void generatesCompliantTraceContext()
    {
        TraceContext context = W3cTraceContextFilter.generateTraceContext();

        assertNotNull(context.traceId());
        assertEquals(32, context.traceId().length());
        assertTrue(context.traceId().matches("[0-9a-f]{32}"));
        assertNotEquals(ZERO_TRACE_ID, context.traceId());
        assertNotNull(context.spanId());
        assertEquals(16, context.spanId().length());
        assertTrue(context.spanId().matches("[0-9a-f]{16}"));
        assertNotEquals(ZERO_SPAN_ID, context.spanId());

        String formatted = W3cTraceContextFilter.formatTraceparent(context);
        assertEquals(55, formatted.length());
        assertTrue(formatted.startsWith("00-"));
    }

    @Test
    @DisplayName("Propagates an inbound trace id into MDC and the request attribute")
    void propagatesInboundTraceId() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/accounts");
        request.addHeader(W3cTraceContextFilter.TRACEPARENT_HEADER, CANONICAL_TRACEPARENT);
        MockHttpServletResponse response = new MockHttpServletResponse();

        AtomicReference<String> traceIdInChain = new AtomicReference<>();
        AtomicReference<TraceContext> contextInChain = new AtomicReference<>();
        MockFilterChain chain = captureChain(traceIdInChain, contextInChain);

        filter.doFilter(request, response, chain);

        assertEquals(INBOUND_TRACE_ID, traceIdInChain.get());
        assertNotNull(contextInChain.get());
        assertEquals(INBOUND_TRACE_ID, contextInChain.get().traceId());
        assertEquals(INBOUND_SPAN_ID, contextInChain.get().parentSpanId());
        assertNull(MDC.get(W3cTraceContextFilter.MDC_TRACE_ID_KEY));
        assertNotNull(response.getHeader(W3cTraceContextFilter.TRACEPARENT_HEADER));
    }

    @Test
    @DisplayName("Generates and injects a new trace id when the header is absent")
    void generatesTraceIdWhenHeaderAbsent() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/accounts");
        MockHttpServletResponse response = new MockHttpServletResponse();

        AtomicReference<String> traceIdInChain = new AtomicReference<>();
        AtomicReference<TraceContext> contextInChain = new AtomicReference<>();
        MockFilterChain chain = captureChain(traceIdInChain, contextInChain);

        filter.doFilter(request, response, chain);

        String generatedTraceId = traceIdInChain.get();
        assertNotNull(generatedTraceId);
        assertEquals(32, generatedTraceId.length());
        assertTrue(generatedTraceId.matches("[0-9a-f]{32}"));
        assertNotEquals(ZERO_TRACE_ID, generatedTraceId);
        assertNotNull(contextInChain.get());
        assertEquals(generatedTraceId, contextInChain.get().traceId());

        String responseHeader = response.getHeader(W3cTraceContextFilter.TRACEPARENT_HEADER);
        assertNotNull(responseHeader);
        assertEquals(55, responseHeader.length());
        Optional<TraceContext> parsedResponseHeader = W3cTraceContextFilter.parseTraceparent(responseHeader);
        assertTrue(parsedResponseHeader.isPresent());
        assertEquals(generatedTraceId, parsedResponseHeader.get().traceId());

        assertNull(MDC.get(W3cTraceContextFilter.MDC_TRACE_ID_KEY));
        assertNull(MDC.get(W3cTraceContextFilter.MDC_SPAN_ID_KEY));
        assertNull(MDC.get(W3cTraceContextFilter.MDC_PARENT_SPAN_ID_KEY));
    }

    @Test
    @DisplayName("Builds propagation headers that round-trip through traceparent parsing")
    void buildsPropagationHeaders()
    {
        TraceContext context = W3cTraceContextFilter.generateTraceContext();

        Map<String, String> headers = W3cTraceContextFilter.buildPropagationHeaders(context);

        assertEquals(context.traceId(), headers.get(W3cTraceContextFilter.MDC_TRACE_ID_KEY));
        assertEquals(W3cTraceContextFilter.formatTraceparent(context), headers.get(W3cTraceContextFilter.TRACEPARENT_HEADER));

        Optional<TraceContext> parsed = W3cTraceContextFilter.parseTraceparent(
                headers.get(W3cTraceContextFilter.TRACEPARENT_HEADER));
        assertTrue(parsed.isPresent());
        assertEquals(context.traceId(), parsed.get().traceId());
        assertEquals(context.spanId(), parsed.get().parentSpanId());
        assertEquals(context.isSampled(), parsed.get().isSampled());
    }
}
