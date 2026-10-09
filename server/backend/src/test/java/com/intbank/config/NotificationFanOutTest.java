package com.intbank.config;

import com.intbank.infrastructure.persistence.entity.NotificationJpaEntity;
import com.intbank.infrastructure.persistence.repository.NotificationJpaRepository;
import com.intbank.service.NotificationService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.connection.DefaultMessage;
import org.springframework.data.redis.core.RedisTemplate;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** A notification created on one server instance reaches streams open on any instance. */
class NotificationFanOutTest
{

    @Test
    @SuppressWarnings("unchecked")
    void notificationsArePublishedOnceForEveryInstance()
    {
        NotificationJpaRepository repo = mock(NotificationJpaRepository.class);
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        RedisTemplate<String, String> redis = mock(RedisTemplate.class);
        NotificationService service = new NotificationService(repo, redis);

        service.notify(7L, "Bani primiți", "+100 RON", "TRANSFER_RECEIVED");

        ArgumentCaptor<String> message = ArgumentCaptor.forClass(String.class);
        verify(redis).convertAndSend(eq(NotificationService.CHANNEL), message.capture());
        assertTrue(message.getValue().contains("\"userId\":7"));
        assertTrue(message.getValue().contains("Bani primi"));
    }

    @Test
    void eachInstanceDeliversTheMessageToThatCustomer()
    {
        NotificationService service = mock(NotificationService.class);
        var listener = NotificationFanOutConfig.listener(service);
        String json = "{\"id\":5,\"userId\":7,\"title\":\"T\",\"message\":\"M\",\"type\":\"SYSTEM\"}";

        listener.onMessage(new DefaultMessage(NotificationService.CHANNEL.getBytes(), json.getBytes(StandardCharsets.UTF_8)), null);

        verify(service).deliverLocal(eq(7L), argThat((Map<String, Object> p) -> "T".equals(p.get("title"))));
    }

    @Test
    void malformedMessagesAreIgnored()
    {
        NotificationService service = mock(NotificationService.class);
        NotificationFanOutConfig.listener(service)
                .onMessage(new DefaultMessage(new byte[0], "not json".getBytes(StandardCharsets.UTF_8)), null);
        verifyNoInteractions(service);
    }

    @Test
    void withoutRedisTheNotificationIsStillSaved()
    {
        NotificationJpaRepository repo = mock(NotificationJpaRepository.class);
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        NotificationJpaEntity saved = new NotificationService(repo).notify(7L, "T", "M", "SYSTEM");

        assertEquals(7L, saved.getUserId());
    }
}
