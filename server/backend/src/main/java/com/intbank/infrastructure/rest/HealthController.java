package com.intbank.infrastructure.rest;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthController
{

    @GetMapping("/health")
    public Map<String, String> getHealth()
    {
        return Map.of("status", "ok");
    }
}