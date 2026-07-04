package com.intbank.core.port.out;

import java.util.Map;

public interface EventPublisher
{

    void publish(String topic, String key, Map<String, Object> event);
}