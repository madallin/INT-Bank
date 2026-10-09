package com.intbank.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.intbank.service.NotificationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;

import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * Delivers notifications published on {@link NotificationService#CHANNEL} to the live streams
 * open on this instance, so every replica serves its own connected customers.
 */
@Configuration
public class NotificationFanOutConfig
{

    private static final Logger log = LoggerFactory.getLogger(NotificationFanOutConfig.class);
    private static final ObjectMapper JSON = new ObjectMapper();

    @Bean
    public RedisMessageListenerContainer notificationFanOut(RedisConnectionFactory connectionFactory,
                                                            NotificationService notifications)
    {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(connectionFactory);
        container.addMessageListener(listener(notifications), new ChannelTopic(NotificationService.CHANNEL));
        return container;
    }

    static MessageListener listener(NotificationService notifications)
    {
        return (message, pattern) -> {
            try
            {
                Map<String, Object> payload = JSON.readValue(
                        new String(message.getBody(), StandardCharsets.UTF_8), new TypeReference<Map<String, Object>>() { });
                if (payload.get("userId") instanceof Number id)
                {
                    notifications.deliverLocal(id.longValue(), payload);
                }
            }
            catch (Exception e)
            {
                log.warn("Ignoring malformed notification message: {}", e.getMessage());
            }
        };
    }
}
