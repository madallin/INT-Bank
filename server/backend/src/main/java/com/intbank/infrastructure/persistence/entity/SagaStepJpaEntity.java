package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "saga_steps")
public class SagaStepJpaEntity
{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "saga_id", nullable = false, length = 64)
    private String sagaId;

    @Column(name = "step_name", nullable = false, length = 40)
    private String stepName;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "executed_at")
    private Instant executedAt;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public String getSagaId()
    {
        return sagaId;
    }

    public void setSagaId(String sagaId)
    {
        this.sagaId = sagaId;
    }

    public String getStepName()
    {
        return stepName;
    }

    public void setStepName(String stepName)
    {
        this.stepName = stepName;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public Instant getExecutedAt()
    {
        return executedAt;
    }

    public void setExecutedAt(Instant executedAt)
    {
        this.executedAt = executedAt;
    }
}
