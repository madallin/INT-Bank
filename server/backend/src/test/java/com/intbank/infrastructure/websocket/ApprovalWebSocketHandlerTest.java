package com.intbank.infrastructure.websocket;

import com.intbank.infrastructure.security.AuthenticatedClient;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Approval messages reach only the approved customer's connections. */
class ApprovalWebSocketHandlerTest
{

    private final ApprovalWebSocketHandler handler = new ApprovalWebSocketHandler();

    @Test
    void anApprovalGoesOnlyToThatCustomer() throws Exception
    {
        WebSocketSession customer = session(501L);
        WebSocketSession someoneElse = session(502L);
        handler.afterConnectionEstablished(customer);
        handler.afterConnectionEstablished(someoneElse);

        ApprovalWebSocketHandler.notifyApproved(501L);

        verify(customer).sendMessage(new TextMessage("{\"type\":\"contAprobat\",\"id\":501,\"status\":\"approved\"}"));
        verify(someoneElse, never()).sendMessage(any());

        handler.afterConnectionClosed(customer, CloseStatus.NORMAL);
        handler.afterConnectionClosed(someoneElse, CloseStatus.NORMAL);
        assertEquals(0, ApprovalWebSocketHandler.connectionsOf(501L));
    }

    @Test
    void aConnectionWithoutACustomerIsClosed() throws Exception
    {
        WebSocketSession anonymous = mock(WebSocketSession.class);
        when(anonymous.getPrincipal()).thenReturn(null);

        handler.afterConnectionEstablished(anonymous);

        verify(anonymous).close(CloseStatus.POLICY_VIOLATION);
    }

    private static WebSocketSession session(Long userId)
    {
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        when(session.getPrincipal()).thenReturn(new UsernamePasswordAuthenticationToken(
                new AuthenticatedClient("phone", userId, List.of("ROLE_PREAUTH")), null, List.of()));
        return session;
    }
}
