package com.intbank.infrastructure.rest;

import com.intbank.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/notifications")
public class NotificationController
{

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService)
    {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<?> getNotifications(@PathVariable("userId") Long userId)
    {
        var list = notificationService.getNotifications(userId);
        long unread = notificationService.getUnreadCount(userId);
        return ResponseEntity.ok(Map.of(
                "notifications", list,
                "unreadCount", unread
        ));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<?> markAsRead(
            @PathVariable("userId") Long userId,
            @PathVariable("id") Long id)
    {
        notificationService.markAsRead(userId, id);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @GetMapping(value = "/stream", produces = org.springframework.http.MediaType.TEXT_EVENT_STREAM_VALUE)
    public org.springframework.web.servlet.mvc.method.annotation.SseEmitter streamNotifications(
            @PathVariable("userId") Long userId)
    {
        return notificationService.registerEmitter(userId);
    }

    @PostMapping("/device-token")
    public ResponseEntity<?> registerDeviceToken(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, String> body)
    {
        String token = body.get("token");
        String platform = body.getOrDefault("platform", "android");
        notificationService.registerDeviceToken(userId, token, platform);
        return ResponseEntity.ok(Map.of("success", true, "registered", token != null));
    }

    @PutMapping("/read-all")
    public ResponseEntity<?> markAllAsRead(@PathVariable("userId") Long userId)
    {
        notificationService.markAllAsRead(userId);
        return ResponseEntity.ok(Map.of("success", true));
    }
}
