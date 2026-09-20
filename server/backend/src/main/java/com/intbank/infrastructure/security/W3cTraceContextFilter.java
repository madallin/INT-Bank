package com.intbank.infrastructure.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class W3cTraceContextFilter extends OncePerRequestFilter
{
    public static final String TRACEPARENT_HEADER = "traceparent";
    public static final String TRACE_CONTEXT_ATTRIBUTE = "com.intbank.traceContext";
    public static final String MDC_TRACE_ID_KEY = "traceId";
    public static final String MDC_SPAN_ID_KEY = "spanId";
    public static final String MDC_PARENT_SPAN_ID_KEY = "parentSpanId";

    private static final String SUPPORTED_VERSION = "00";
    private static final String SAMPLED_FLAG = "01";
    private static final String NOT_SAMPLED_FLAG = "00";
    private static final int TRACEPARENT_LENGTH = 55;
    private static final int TRACE_ID_LENGTH = 32;
    private static final int SPAN_ID_LENGTH = 16;
    private static final String ZERO_TRACE_ID = "00000000000000000000000000000000";
    private static final String ZERO_SPAN_ID = "0000000000000000";

    private static final Pattern VERSION_PATTERN = Pattern.compile("^[0-9a-f]{2}$");
    private static final Pattern TRACE_ID_PATTERN = Pattern.compile("^[0-9a-f]{32}$");
    private static final Pattern SPAN_ID_PATTERN = Pattern.compile("^[0-9a-f]{16}$");
    private static final Pattern FLAGS_PATTERN = Pattern.compile("^[0-9a-f]{2}$");

    private static final char[] HEX_DIGITS = "0123456789abcdef".toCharArray();
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    public record TraceContext(String traceId, String parentSpanId, String spanId, boolean isSampled)
    {
    }

    public static Optional<TraceContext> parseTraceparent(String header)
    {
        if (header == null || header.length() != TRACEPARENT_LENGTH)
        {
            return Optional.empty();
        }

        String[] parts = header.split("-", -1);
        if (parts.length != 4)
        {
            return Optional.empty();
        }

        String version = parts[0];
        String traceId = parts[1];
        String parentSpanId = parts[2];
        String flags = parts[3];

        if (!VERSION_PATTERN.matcher(version).matches() || !SUPPORTED_VERSION.equals(version))
        {
            return Optional.empty();
        }
        if (!TRACE_ID_PATTERN.matcher(traceId).matches() || ZERO_TRACE_ID.equals(traceId))
        {
            return Optional.empty();
        }
        if (!SPAN_ID_PATTERN.matcher(parentSpanId).matches() || ZERO_SPAN_ID.equals(parentSpanId))
        {
            return Optional.empty();
        }
        if (!FLAGS_PATTERN.matcher(flags).matches())
        {
            return Optional.empty();
        }

        boolean isSampled = (Integer.parseInt(flags, 16) & 0x01) == 0x01;
        return Optional.of(new TraceContext(traceId, parentSpanId, randomHex(SPAN_ID_LENGTH), isSampled));
    }

    public static TraceContext generateTraceContext()
    {
        return new TraceContext(randomHex(TRACE_ID_LENGTH), ZERO_SPAN_ID, randomHex(SPAN_ID_LENGTH), true);
    }

    public static String formatTraceparent(TraceContext context)
    {
        String flags = context.isSampled() ? SAMPLED_FLAG : NOT_SAMPLED_FLAG;
        return SUPPORTED_VERSION + "-" + context.traceId() + "-" + context.spanId() + "-" + flags;
    }

    public static Map<String, String> buildPropagationHeaders(TraceContext context)
    {
        Map<String, String> headers = new HashMap<>();
        headers.put(TRACEPARENT_HEADER, formatTraceparent(context));
        headers.put(MDC_TRACE_ID_KEY, context.traceId());
        return headers;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException
    {
        String inboundHeader = request.getHeader(TRACEPARENT_HEADER);
        TraceContext context = parseTraceparent(inboundHeader).orElseGet(W3cTraceContextFilter::generateTraceContext);

        try
        {
            MDC.put(MDC_TRACE_ID_KEY, context.traceId());
            MDC.put(MDC_SPAN_ID_KEY, context.spanId());
            MDC.put(MDC_PARENT_SPAN_ID_KEY, context.parentSpanId());
            request.setAttribute(TRACE_CONTEXT_ATTRIBUTE, context);
            response.setHeader(TRACEPARENT_HEADER, formatTraceparent(context));
            chain.doFilter(request, response);
        }
        finally
        {
            MDC.remove(MDC_TRACE_ID_KEY);
            MDC.remove(MDC_SPAN_ID_KEY);
            MDC.remove(MDC_PARENT_SPAN_ID_KEY);
        }
    }

    private static String randomHex(int length)
    {
        char[] buffer = new char[length];
        for (int index = 0; index < length; index++)
        {
            buffer[index] = HEX_DIGITS[SECURE_RANDOM.nextInt(HEX_DIGITS.length)];
        }
        return new String(buffer);
    }
}
