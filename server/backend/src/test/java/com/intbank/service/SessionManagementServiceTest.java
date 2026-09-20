package com.intbank.service;

import com.intbank.service.SessionManagementService.SessionStatus;
import com.intbank.service.SessionManagementService.SessionValidationResult;
import com.intbank.service.SessionManagementService.UserSessionRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class SessionManagementServiceTest
{

    private Instant now;
    private SessionManagementService service;

    @BeforeEach
    void setUp()
    {
        now = Instant.parse("2026-01-01T00:00:00Z");
        service = new SessionManagementService(() -> now);
    }

    @Test
    void registerSession_storesFieldsAndUsesInjectedTime()
    {
        UserSessionRecord record = service.registerSession("s-1", 10L, "Pixel 8", "Android 15",
                "10.0.0.1", "Bucharest");

        assertEquals("s-1", record.sessionId());
        assertEquals(10L, record.userId());
        assertEquals("Pixel 8", record.deviceModel());
        assertEquals("Android 15", record.osVersion());
        assertEquals("10.0.0.1", record.ipAddress());
        assertEquals("Bucharest", record.geoCity());
        assertEquals(now, record.lastSeenAt());
        assertFalse(record.isCurrent());

        UserSessionRecord found = service.findSession("s-1").orElseThrow();
        assertEquals(now, found.lastSeenAt());
    }

    @Test
    void listUserSessions_ordersNewestFirstAndFlagsCurrent()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");
        now = now.plus(Duration.ofMinutes(5));
        service.registerSession("s-2", 10L, "iPhone 16", "iOS 19", "10.0.0.2", "Cluj");
        now = now.plus(Duration.ofMinutes(5));
        service.registerSession("s-3", 10L, "MacBook", "macOS 16", "10.0.0.3", "Iasi");

        List<UserSessionRecord> sessions = service.listUserSessions(10L, "s-2");

        assertEquals(3, sessions.size());
        assertEquals("s-3", sessions.get(0).sessionId());
        assertEquals("s-2", sessions.get(1).sessionId());
        assertEquals("s-1", sessions.get(2).sessionId());
        assertTrue(sessions.get(1).isCurrent());
        assertFalse(sessions.get(0).isCurrent());
        assertFalse(sessions.get(2).isCurrent());
    }

    @Test
    void listUserSessions_isolatesUsers()
    {
        service.registerSession("a-1", 1L, "Pixel", "Android", "1.1.1.1", "A");
        now = now.plus(Duration.ofMinutes(1));
        service.registerSession("b-1", 2L, "iPhone", "iOS", "2.2.2.2", "B");

        List<UserSessionRecord> userOne = service.listUserSessions(1L);
        List<UserSessionRecord> userTwo = service.listUserSessions(2L);

        assertEquals(1, userOne.size());
        assertEquals("a-1", userOne.get(0).sessionId());
        assertEquals(1, userTwo.size());
        assertEquals("b-1", userTwo.get(0).sessionId());
    }

    @Test
    void revokeSession_marksSessionRevokedAndValidationReturns401()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");

        boolean revoked = service.revokeSession("s-1");

        assertTrue(revoked);
        SessionValidationResult result = service.validateSession("s-1");
        assertFalse(result.valid());
        assertEquals(401, result.httpStatus());
        assertEquals("SessionRevoked", result.code());
        assertEquals(SessionStatus.REVOKED, result.status());
    }

    @Test
    void revokeAllOtherSessions_keepsCurrentAndRevokesOthers()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");
        now = now.plus(Duration.ofMinutes(1));
        service.registerSession("s-2", 10L, "iPhone 16", "iOS 19", "10.0.0.2", "Cluj");
        now = now.plus(Duration.ofMinutes(1));
        service.registerSession("s-3", 10L, "MacBook", "macOS 16", "10.0.0.3", "Iasi");
        now = now.plus(Duration.ofMinutes(1));
        service.registerSession("other-1", 99L, "Other", "Other", "9.9.9.9", "Other");

        int revokedCount = service.revokeAllOtherSessions("s-1");

        assertEquals(2, revokedCount);
        SessionValidationResult current = service.validateSession("s-1");
        assertTrue(current.valid());
        assertEquals(200, current.httpStatus());
        assertEquals("OK", current.code());
        assertEquals(SessionStatus.REVOKED, service.validateSession("s-2").status());
        assertEquals(SessionStatus.REVOKED, service.validateSession("s-3").status());
        assertEquals(SessionStatus.ACTIVE, service.validateSession("other-1").status());
    }

    @Test
    void revokeUnknownOrBlank_returnsFalseAndBlankValidationNotFound()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");

        assertFalse(service.revokeSession("missing"));
        assertFalse(service.revokeSession("   "));
        assertFalse(service.revokeSession(null));

        SessionValidationResult blank = service.validateSession("   ");
        assertFalse(blank.valid());
        assertEquals(404, blank.httpStatus());
        assertEquals("SessionNotFound", blank.code());
        assertEquals(SessionStatus.NOT_FOUND, blank.status());
    }

    @Test
    void touchSession_updatesLastSeenAtWithInjectedTime()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");
        Instant originalLastSeen = service.findSession("s-1").orElseThrow().lastSeenAt();

        now = now.plus(Duration.ofMinutes(30));
        service.touchSession("s-1");

        UserSessionRecord touched = service.findSession("s-1").orElseThrow();
        assertNotNull(touched.lastSeenAt());
        assertEquals(now, touched.lastSeenAt());
        assertTrue(touched.lastSeenAt().isAfter(originalLastSeen));
    }

    @Test
    void lastSeenAt_isDeterministicWithAdvancedClock()
    {
        service.registerSession("s-1", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest");
        Instant firstSeen = service.findSession("s-1").orElseThrow().lastSeenAt();

        now = now.plus(Duration.ofHours(2));
        service.touchSession("s-1");
        Instant secondSeen = service.findSession("s-1").orElseThrow().lastSeenAt();

        assertEquals(Instant.parse("2026-01-01T00:00:00Z"), firstSeen);
        assertEquals(Instant.parse("2026-01-01T02:00:00Z"), secondSeen);
        assertEquals(Duration.ofHours(2), Duration.between(firstSeen, secondSeen));
    }

    @Test
    void registerSession_rejectsBlankIdOrNullUserId()
    {
        assertThrows(IllegalArgumentException.class, () ->
                service.registerSession("   ", 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest"));
        assertThrows(IllegalArgumentException.class, () ->
                service.registerSession(null, 10L, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest"));
        assertThrows(IllegalArgumentException.class, () ->
                service.registerSession("s-1", null, "Pixel 8", "Android 15", "10.0.0.1", "Bucharest"));
    }
}
