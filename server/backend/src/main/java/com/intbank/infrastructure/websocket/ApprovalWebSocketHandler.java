package com.intbank.infrastructure.websocket;

import com.intbank.infrastructure.security.AuthenticatedClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tells a waiting customer that their account was approved.
 *
 * <p>The handshake is authenticated (onboarding or full token, see SecurityConfig); each
 * connection is filed under the customer in its token, and an approval is sent only to that
 * customer's connections. (It used to be broadcast to every connected client.)
 */
public class ApprovalWebSocketHandler extends TextWebSocketHandler
{

    private static final Logger log = LoggerFactory.getLogger(ApprovalWebSocketHandler.class);
    private static final Map<Long, Set<WebSocketSession>> sessionsByUser = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception
    {
        Long userId = customerOf(session);
        if (userId == null)
        {
            session.close(CloseStatus.POLICY_VIOLATION);
            return;
        }
        sessionsByUser.computeIfAbsent(userId, id -> ConcurrentHashMap.newKeySet()).add(session);
        log.info("Approval socket connected for user {}", userId);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception
    {
        session.sendMessage(new TextMessage("{\"type\":\"ack\"}"));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status)
    {
        Long userId = customerOf(session);
        if (userId != null)
        {
            sessionsByUser.computeIfPresent(userId, (id, set) -> {
                set.remove(session);
                return set.isEmpty() ? null : set;
            });
        }
    }

    /** Sends the approval to the connections of [userId] only. */
    public static void notifyApproved(Long userId)
    {
        String message = "{\"type\":\"contAprobat\",\"id\":" + userId + ",\"status\":\"approved\"}";
        for (WebSocketSession session : sessionsByUser.getOrDefault(userId, Set.of()))
        {
            try
            {
                if (session.isOpen()) session.sendMessage(new TextMessage(message));
            }
            catch (Exception e)
            {
                log.warn("Approval message to user {} failed: {}", userId, e.getMessage());
            }
        }
    }

    static int connectionsOf(Long userId)
    {
        return sessionsByUser.getOrDefault(userId, Set.of()).size();
    }

    private static Long customerOf(WebSocketSession session)
    {
        return session.getPrincipal() instanceof Authentication auth
                && auth.getPrincipal() instanceof AuthenticatedClient client ? client.userId() : null;
    }
}
