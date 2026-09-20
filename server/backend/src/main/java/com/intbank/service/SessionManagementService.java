package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class SessionManagementService
{

    private static final Logger log = LoggerFactory.getLogger(SessionManagementService.class);
    private static final Duration SESSION_TTL = Duration.ofHours(12);

    private final InstantSupplier clock;
    private final ConcurrentHashMap<String, UserSessionRecord> sessions = new ConcurrentHashMap<>();
    private final Set<String> revokedSessionIds = ConcurrentHashMap.newKeySet();

    @FunctionalInterface
    public interface InstantSupplier
    {
        Instant now();
    }

    public record UserSessionRecord(String sessionId, Long userId, String deviceModel, String osVersion,
                                    String ipAddress, String geoCity, Instant lastSeenAt, boolean isCurrent)
    {
    }

    public enum SessionStatus
    {
        ACTIVE,
        REVOKED,
        EXPIRED,
        NOT_FOUND
    }

    public record SessionValidationResult(boolean valid, int httpStatus, String code, SessionStatus status)
    {
        public static SessionValidationResult active()
        {
            return new SessionValidationResult(true, 200, "OK", SessionStatus.ACTIVE);
        }

        public static SessionValidationResult revoked()
        {
            return new SessionValidationResult(false, 401, "SessionRevoked", SessionStatus.REVOKED);
        }

        public static SessionValidationResult expired()
        {
            return new SessionValidationResult(false, 401, "SessionExpired", SessionStatus.EXPIRED);
        }

        public static SessionValidationResult notFound()
        {
            return new SessionValidationResult(false, 404, "SessionNotFound", SessionStatus.NOT_FOUND);
        }
    }

    public SessionManagementService()
    {
        this(Instant::now);
    }

    SessionManagementService(InstantSupplier clock)
    {
        this.clock = clock;
    }

    public UserSessionRecord registerSession(String sessionId, Long userId, String deviceModel, String osVersion,
                                             String ipAddress, String geoCity)
    {
        if (sessionId == null || sessionId.isBlank())
        {
            throw new IllegalArgumentException("sessionId must not be blank");
        }
        if (userId == null)
        {
            throw new IllegalArgumentException("userId must not be null");
        }

        UserSessionRecord record = new UserSessionRecord(sessionId, userId, deviceModel, osVersion,
                ipAddress, geoCity, clock.now(), false);
        sessions.put(sessionId, record);
        revokedSessionIds.remove(sessionId);
        log.info("Session registered: id={}, user={}, device={}, city={}", sessionId, userId, deviceModel, geoCity);
        return record;
    }

    public Optional<UserSessionRecord> findSession(String sessionId)
    {
        if (sessionId == null || sessionId.isBlank())
        {
            return Optional.empty();
        }
        return Optional.ofNullable(sessions.get(sessionId));
    }

    public List<UserSessionRecord> listUserSessions(Long userId)
    {
        return listUserSessions(userId, null);
    }

    public List<UserSessionRecord> listUserSessions(Long userId, String currentSessionId)
    {
        List<UserSessionRecord> result = new ArrayList<>();
        if (userId == null)
        {
            return result;
        }

        for (UserSessionRecord record : sessions.values())
        {
            if (record.userId().equals(userId))
            {
                boolean isCurrent = currentSessionId != null && currentSessionId.equals(record.sessionId());
                result.add(new UserSessionRecord(record.sessionId(), record.userId(), record.deviceModel(),
                        record.osVersion(), record.ipAddress(), record.geoCity(), record.lastSeenAt(), isCurrent));
            }
        }

        result.sort(Comparator.comparing(UserSessionRecord::lastSeenAt).reversed());
        return result;
    }

    public boolean revokeSession(String sessionId)
    {
        if (sessionId == null || sessionId.isBlank())
        {
            return false;
        }

        UserSessionRecord record = sessions.get(sessionId);
        if (record == null)
        {
            return false;
        }

        revokedSessionIds.add(sessionId);
        log.warn("Session revoked: id={}, user={}", sessionId, record.userId());
        return true;
    }

    public int revokeAllOtherSessions(String currentSessionId)
    {
        if (currentSessionId == null || currentSessionId.isBlank())
        {
            return 0;
        }

        UserSessionRecord current = sessions.get(currentSessionId);
        if (current == null)
        {
            return 0;
        }

        int revokedCount = 0;
        for (UserSessionRecord record : sessions.values())
        {
            if (record.userId().equals(current.userId()) && !record.sessionId().equals(currentSessionId))
            {
                if (revokedSessionIds.add(record.sessionId()))
                {
                    revokedCount++;
                }
            }
        }

        log.info("Remote kill switch: revoked {} other session(s) for user {}", revokedCount, current.userId());
        return revokedCount;
    }

    public SessionValidationResult validateSession(String sessionId)
    {
        if (sessionId == null || sessionId.isBlank())
        {
            return SessionValidationResult.notFound();
        }

        UserSessionRecord record = sessions.get(sessionId);
        if (record == null)
        {
            return SessionValidationResult.notFound();
        }

        if (revokedSessionIds.contains(sessionId))
        {
            return SessionValidationResult.revoked();
        }

        if (isExpired(record, clock.now()))
        {
            return SessionValidationResult.expired();
        }

        return SessionValidationResult.active();
    }

    public void touchSession(String sessionId)
    {
        if (sessionId == null || sessionId.isBlank())
        {
            return;
        }

        sessions.computeIfPresent(sessionId, (key, existing) ->
        {
            if (revokedSessionIds.contains(key))
            {
                return existing;
            }
            return new UserSessionRecord(existing.sessionId(), existing.userId(), existing.deviceModel(),
                    existing.osVersion(), existing.ipAddress(), existing.geoCity(), clock.now(), existing.isCurrent());
        });
    }

    private boolean isExpired(UserSessionRecord record, Instant now)
    {
        return record.lastSeenAt().plus(SESSION_TTL).isBefore(now);
    }
}
