package com.intbank.infrastructure.rest;

import com.intbank.service.OutboxProcessorService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/admin")
public class AdminController
{

    private final OutboxProcessorService outboxProcessor;

    public AdminController(OutboxProcessorService outboxProcessor)
    {
        this.outboxProcessor = outboxProcessor;
    }

    @GetMapping("/outbox/stats")
    public Map<String, Object> getOutboxStats()
    {
        return Map.of("data", outboxProcessor.getStats());
    }

    @PostMapping("/outbox/reprocess-dead")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> reprocessDeadOutbox()
    {
        int count = outboxProcessor.reprocessDead();
        return Map.of("message", count + " dead messages queued for reprocessing", "count", count);
    }

    @PostMapping("/outbox/process-now")
    public Map<String, Object> processOutboxNow()
    {
        var result = outboxProcessor.processNow();
        return Map.of("message", "Processed " + result.get("processed") + ", failed " + result.get("failed"), "data", result);
    }

    @GetMapping("/dlq/stats")
    public Map<String, Object> getDlqStats()
    {
        var stats = outboxProcessor.getStats();
        return Map.of("data", Map.of(
                "deadMessages", stats.get("dead"),
                "pendingRetries", stats.get("pending"),
                "permanentlyFailed", stats.get("dead"),
                "totalMessages", stats.get("total")
        ));
    }

    @GetMapping("/balances")
    public Map<String, String> getBalanceCacheStats()
    {
        return Map.of("message", "Read model projector is operational");
    }
}