package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.NotificationJpaEntity;
import com.intbank.infrastructure.persistence.repository.NotificationJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class NotificationService
{

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationJpaRepository notificationRepo;
    private final Map<Long, List<SseEmitter>> userEmitters = new ConcurrentHashMap<>();
    private final Map<Long, Set<String>> userDeviceTokens = new ConcurrentHashMap<>();

    public NotificationService(NotificationJpaRepository notificationRepo)
    {
        this.notificationRepo = notificationRepo;
    }

    public SseEmitter registerEmitter(Long userId)
    {
        SseEmitter emitter = new SseEmitter(1800000L); // 30 minutes
        userEmitters.computeIfAbsent(userId, k -> new CopyOnWriteArrayList<>()).add(emitter);

        emitter.onCompletion(() -> removeEmitter(userId, emitter));
        emitter.onTimeout(() -> removeEmitter(userId, emitter));
        emitter.onError((e) -> removeEmitter(userId, emitter));

        try
        {
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data(Map.of("status", "connected", "userId", userId, "timestamp", Instant.now().toString())));
            log.info("Registered real-time push SSE emitter for user {}", userId);
        }
        catch (Exception e)
        {
            removeEmitter(userId, emitter);
        }

        return emitter;
    }

    private void removeEmitter(Long userId, SseEmitter emitter)
    {
        List<SseEmitter> list = userEmitters.get(userId);
        if (list != null)
        {
            list.remove(emitter);
            if (list.isEmpty())
            {
                userEmitters.remove(userId);
            }
        }
    }

    public void registerDeviceToken(Long userId, String token, String platform)
    {
        if (token != null && !token.isBlank())
        {
            userDeviceTokens.computeIfAbsent(userId, k -> ConcurrentHashMap.newKeySet()).add(token.trim());
            log.info("Registered {} device token for user {}: {}", platform, userId, token);
        }
    }

    public Set<String> getDeviceTokens(Long userId)
    {
        return userDeviceTokens.getOrDefault(userId, Collections.emptySet());
    }

    @Transactional
    public NotificationJpaEntity notify(Long userId, String title, String message, String type)
    {
        NotificationJpaEntity n = new NotificationJpaEntity();
        n.setUserId(userId);
        n.setTitle(title);
        n.setMessage(message);
        n.setType(type);
        n.setRead(false);
        n.setCreatedAt(Instant.now());

        log.info("Creating notification for user {}: [{}] {}", userId, type, title);
        NotificationJpaEntity saved = notificationRepo.save(n);

        broadcastPushEvent(userId, saved);

        return saved;
    }

    private void broadcastPushEvent(Long userId, NotificationJpaEntity entity)
    {
        List<SseEmitter> emitters = userEmitters.get(userId);
        if (emitters != null && !emitters.isEmpty())
        {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("id", entity.getId());
            payload.put("userId", entity.getUserId());
            payload.put("title", entity.getTitle());
            payload.put("message", entity.getMessage());
            payload.put("type", entity.getType());
            payload.put("createdAt", entity.getCreatedAt().toString());

            for (SseEmitter emitter : emitters)
            {
                try
                {
                    emitter.send(SseEmitter.event()
                            .name("NOTIFICATION")
                            .data(payload));
                    log.debug("Sent real-time push event to user {}", userId);
                }
                catch (Exception e)
                {
                    emitter.complete();
                    removeEmitter(userId, emitter);
                }
            }
        }
    }

    @Transactional(readOnly = true)
    public List<NotificationJpaEntity> getNotifications(Long userId)
    {
        return notificationRepo.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional(readOnly = true)
    public long getUnreadCount(Long userId)
    {
        return notificationRepo.countByUserIdAndIsReadFalse(userId);
    }

    @Transactional
    public void markAsRead(Long userId, Long notificationId)
    {
        notificationRepo.findById(notificationId)
                .filter(n -> n.getUserId().equals(userId))
                .ifPresent(n -> {
                    n.setRead(true);
                    notificationRepo.save(n);
                });
    }

    @Transactional
    public void markAllAsRead(Long userId)
    {
        List<NotificationJpaEntity> list = notificationRepo.findByUserIdOrderByCreatedAtDesc(userId);
        for (NotificationJpaEntity n : list)
        {
            if (!n.isRead())
            {
                n.setRead(true);
                notificationRepo.save(n);
            }
        }
    }
}
