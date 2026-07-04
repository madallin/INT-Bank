package com.intbank.infrastructure.websocket;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class ApprovalWebSocketHandler extends TextWebSocketHandler
{

    private static final Logger log = LoggerFactory.getLogger(ApprovalWebSocketHandler.class);
    private static final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session)
    {
        sessions.put(session.getId(), session);
        log.info("WebSocket connected: {}", session.getId());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception
    {
        log.debug("WebSocket message from {}: {}", session.getId(), message.getPayload());
        // Echo or broadcast to other sessions as needed
        session.sendMessage(new TextMessage("{\"type\":\"ack\",\"message\":\"received\"}"));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status)
    {
        sessions.remove(session.getId());
        log.info("WebSocket disconnected: {} (status: {})", session.getId(), status);
    }

    public static void broadcast(String message)
    {
        sessions.values().forEach(session -> {
            try {
                if (session.isOpen()) {
                    session.sendMessage(new TextMessage(message));
                }
            } catch (Exception e) {
                log.error("WebSocket broadcast error", e);
            }
        });
    }
}