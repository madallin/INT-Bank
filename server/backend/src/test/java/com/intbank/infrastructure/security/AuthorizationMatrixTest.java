package com.intbank.infrastructure.security;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.TreeSet;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Audit finding F3 (BOLA/IDOR). Enumerates every handler of every {@code @RestController}
 * and proves that each route naming a customer ({@code /users/{id}/...}) is reachable only
 * by that customer or an admin. A new controller is covered automatically; one whose
 * path would escape the filter fails this test.
 */
class AuthorizationMatrixTest
{

    private static final long OWNER = 7L;
    private static final long OTHER = 8L;

    private final UserScopeAuthorizationFilter filter = new UserScopeAuthorizationFilter();

    @AfterEach
    void clear()
    {
        SecurityContextHolder.clearContext();
    }

    @Test
    void everyUserScopedRouteIsOwnerOrAdminOnly() throws Exception
    {
        List<Route> routes = userScopedRoutes();
        // Guard against the scan silently finding nothing (e.g. after a package move).
        assertTrue(routes.size() >= 30, "expected the full route set, found " + routes.size() + ": " + routes);

        List<String> failures = new ArrayList<>();
        for (Route route : routes)
        {
            expect(failures, route, null, 401);
            expect(failures, route, new AuthenticatedClient("device-only", null, List.of("ROLE_USER")), 403);
            expect(failures, route, new AuthenticatedClient("phone", OTHER, List.of("ROLE_USER")), 403);
            expect(failures, route, new AuthenticatedClient("phone", OWNER, List.of("ROLE_USER")), 200);
            expect(failures, route, new AuthenticatedClient("admin", 1L, List.of("ROLE_ADMIN")), 200);
        }
        assertTrue(failures.isEmpty(), String.join("\n", failures));
    }

    @Test
    void routesThatNameNoCustomerAreUntouched() throws Exception
    {
        for (String path : List.of("/transfers", "/currency/api/v1/exchange-rates", "/auth/get-client-token", "/admin/outbox/stats"))
        {
            assertEquals(200, run("GET", path, null), path);
        }
    }

    @Test
    void malformedOrMissingUserIdIsRejected() throws Exception
    {
        var owner = new AuthenticatedClient("phone", OWNER, List.of("ROLE_USER"));
        assertEquals(403, run("GET", "/users//beneficiaries", owner));
        assertEquals(403, run("GET", "/users/7abc/beneficiaries", owner));
        assertEquals(403, run("GET", "/currency/api/v1/users/8/exchange/internal", owner));
    }

    private void expect(List<String> failures, Route route, AuthenticatedClient client, int expected) throws Exception
    {
        int actual = run(route.method(), route.concretePath(), client);
        if (actual != expected)
        {
            String who = client == null ? "anonymous" : client.deviceId() + "/uid=" + client.userId() + "/" + client.roles();
            failures.add(route + " as " + who + ": expected " + expected + " but was " + actual);
        }
    }

    /** Returns the filter's status, or 200 when it let the request through to the controller. */
    private int run(String method, String path, AuthenticatedClient client) throws Exception
    {
        SecurityContextHolder.clearContext();
        if (client != null)
        {
            SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(client, null, List.of()));
        }
        MockHttpServletRequest request = new MockHttpServletRequest(method, path);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);
        filter.doFilter(request, response, chain);
        boolean passed = !mockingDetails(chain).getInvocations().isEmpty();
        return passed ? 200 : response.getStatus();
    }

    record Route(String method, String template, String concretePath)
    {
        @Override
        public String toString()
        {
            return method + " " + template;
        }
    }

    private static List<Route> userScopedRoutes() throws ClassNotFoundException
    {
        ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
        scanner.addIncludeFilter(new AnnotationTypeFilter(RestController.class));
        List<Route> routes = new ArrayList<>();
        TreeSet<String> seen = new TreeSet<>();
        for (BeanDefinition definition : scanner.findCandidateComponents("com.intbank"))
        {
            Class<?> controller = Class.forName(definition.getBeanClassName());
            RequestMapping classMapping = AnnotatedElementUtils.findMergedAnnotation(controller, RequestMapping.class);
            String[] prefixes = classMapping != null && classMapping.path().length > 0 ? classMapping.path() : new String[]{""};
            for (Method handler : controller.getDeclaredMethods())
            {
                RequestMapping mapping = AnnotatedElementUtils.findMergedAnnotation(handler, RequestMapping.class);
                if (mapping == null) continue;
                String[] suffixes = mapping.path().length > 0 ? mapping.path() : new String[]{""};
                RequestMethod[] methods = mapping.method().length > 0 ? mapping.method() : new RequestMethod[]{RequestMethod.GET};
                for (String prefix : prefixes)
                {
                    for (String suffix : suffixes)
                    {
                        String template = prefix + suffix;
                        if (!template.contains("users/{")) continue;
                        for (RequestMethod method : methods)
                        {
                            if (seen.add(method + " " + template))
                            {
                                routes.add(new Route(method.name(), template, concrete(template)));
                            }
                        }
                    }
                }
            }
        }
        return routes;
    }

    /** The variable right after {@code users/} becomes the owner's id; any other variable becomes 1. */
    private static String concrete(String template)
    {
        String withOwner = template.replaceFirst("users/\\{[^}]+}", "users/" + OWNER);
        return withOwner.replaceAll("\\{[^}]+}", "1");
    }
}
