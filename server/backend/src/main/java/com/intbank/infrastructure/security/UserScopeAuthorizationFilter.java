package com.intbank.infrastructure.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Object-level authorization for every route that names a customer in its path
 * ({@code /users/{userId}/...}, including {@code /currency/api/v1/users/{userId}/...}).
 *
 * <p>The caller must hold a token whose {@code uid} equals that id, or {@code ROLE_ADMIN}.
 * A device token without a {@code uid} is never enough. Enforcing this centrally means a new
 * controller cannot forget the check; {@code AuthorizationMatrixTest} enumerates every mapped
 * route to prove it.
 */
public class UserScopeAuthorizationFilter extends OncePerRequestFilter
{

    /** First {@code users/<segment>} in the path; the segment may be empty or non-numeric. */
    static final Pattern USER_SCOPED_PATH = Pattern.compile("(?:^|/)users/([^/]*)(?:/|$)");

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException
    {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        Matcher matcher = USER_SCOPED_PATH.matcher(path);
        if (!matcher.find())
        {
            chain.doFilter(request, response);
            return;
        }

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthenticatedClient client))
        {
            reject(response, HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized");
            return;
        }
        if (client.hasRole("ROLE_ADMIN"))
        {
            chain.doFilter(request, response);
            return;
        }

        Long pathUserId = parseId(matcher.group(1));
        if (pathUserId == null || client.userId() == null || !pathUserId.equals(client.userId()))
        {
            reject(response, HttpServletResponse.SC_FORBIDDEN, "Acces interzis");
            return;
        }
        chain.doFilter(request, response);
    }

    private static Long parseId(String raw)
    {
        try
        {
            return Long.valueOf(raw);
        }
        catch (NumberFormatException e)
        {
            return null;
        }
    }

    private static void reject(HttpServletResponse response, int status, String error) throws IOException
    {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write("{\"status\":" + status + ",\"error\":\"" + error + "\"}");
    }
}
