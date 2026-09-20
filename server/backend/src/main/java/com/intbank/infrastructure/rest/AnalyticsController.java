package com.intbank.infrastructure.rest;

import com.intbank.service.AnalyticsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/accounts/{accountId}/analytics")
public class AnalyticsController
{

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService)
    {
        this.analyticsService = analyticsService;
    }

    @GetMapping
    public ResponseEntity<?> getSpendingAnalytics(
            @PathVariable("userId") Long userId,
            @PathVariable("accountId") Long accountId,
            @RequestParam(value = "month", required = false) String monthStr)
    {
        YearMonth ym = monthStr != null && !monthStr.isBlank()
                ? YearMonth.parse(monthStr)
                : YearMonth.now();

        try
        {
            var analytics = analyticsService.getMonthlySpending(userId, accountId, ym);
            return ResponseEntity.ok(analytics);
        }
        catch (IllegalArgumentException e)
        {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
