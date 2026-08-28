package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "processed_events")
public class ProcessedEventJpaEntity
{

    @Id
    @Column(name = "event_key", length = 128)
    private String eventKey;

    @Column(name = "topic", length = 64)
    private String topic;

    @Column(name = "offset")
    private long kafkaOffset;

    @Column(name = "processed_at")
    private Instant processedAt;

    public String getEventKey()
    {
        return eventKey;
    }

    public void setEventKey(String eventKey)
    {
        this.eventKey = eventKey;
    }

    public String getTopic()
    {
        return topic;
    }

    public void setTopic(String topic)
    {
        this.topic = topic;
    }

    public long getKafkaOffset()
    {
        return kafkaOffset;
    }

    public void setKafkaOffset(long kafkaOffset)
    {
        this.kafkaOffset = kafkaOffset;
    }

    public Instant getProcessedAt()
    {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt)
    {
        this.processedAt = processedAt;
    }
}
