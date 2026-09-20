package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.*;
import java.util.*;

@Service
public class AnalyticsService
{

    private final AccountJpaRepository accountRepo;
    private final TransferJpaRepository transferRepo;

    public AnalyticsService(AccountJpaRepository accountRepo, TransferJpaRepository transferRepo)
    {
        this.accountRepo = accountRepo;
        this.transferRepo = transferRepo;
    }

    public record CategorySpending(
            String categoryKey,
            String categoryName,
            BigDecimal amount,
            double percentage,
            int transactionCount
    ) {}

    public record SpendingAnalyticsResponse(
            Long accountId,
            String currency,
            String month, // YYYY-MM
            BigDecimal totalSpent,
            int totalTransactions,
            String topCategory,
            List<CategorySpending> categories
    ) {}

    @Transactional(readOnly = true)
    public SpendingAnalyticsResponse getMonthlySpending(Long userId, Long accountId, YearMonth yearMonth)
    {
        AccountJpaEntity account = accountRepo.findById(accountId)
                .filter(a -> a.getUserId() != null && a.getUserId().equals(userId))
                .orElseThrow(() -> new IllegalArgumentException("Cont inexistent"));

        LocalDate startDate = yearMonth.atDay(1);
        LocalDate endDate = yearMonth.atEndOfMonth();
        Instant startInstant = startDate.atStartOfDay(ZoneId.systemDefault()).toInstant();
        Instant endInstant = endDate.atTime(LocalTime.MAX).atZone(ZoneId.systemDefault()).toInstant();

        List<TransferJpaEntity> allTransfers = transferRepo.findAll();

        Map<String, BigDecimal> categorySums = new LinkedHashMap<>();
        Map<String, Integer> categoryCounts = new LinkedHashMap<>();

        // Initialize standard categories
        for (String cat : List.of("ALIMENTE", "UTILITATI", "RESTAURANTE", "TRANSPORT", "DIVERTISMENT", "ALTELE"))
        {
            categorySums.put(cat, BigDecimal.ZERO);
            categoryCounts.put(cat, 0);
        }

        BigDecimal totalSpent = BigDecimal.ZERO;
        int count = 0;

        for (TransferJpaEntity t : allTransfers)
        {
            if (t.getFromAccount() == null || !t.getFromAccount().getId().equals(accountId)) continue;
            if (!"COMPLETED".equalsIgnoreCase(t.getStatus()) && !"PENDING".equalsIgnoreCase(t.getStatus())) continue;

            Instant txTime = t.getInitiatedAt();
            if (txTime == null || txTime.isBefore(startInstant) || txTime.isAfter(endInstant)) continue;

            String cat = categorize(t.getReason(), t.getToAccount() != null ? t.getToAccount().getIBAN() : "");
            BigDecimal amt = t.getAmount() != null ? t.getAmount() : BigDecimal.ZERO;

            categorySums.put(cat, categorySums.get(cat).add(amt));
            categoryCounts.put(cat, categoryCounts.get(cat) + 1);
            totalSpent = totalSpent.add(amt);
            count++;
        }

        List<CategorySpending> categories = new ArrayList<>();
        String topCat = "Nicio cheltuială";
        BigDecimal maxSpent = BigDecimal.ZERO;

        for (var entry : categorySums.entrySet())
        {
            BigDecimal amt = entry.getValue().setScale(2, RoundingMode.HALF_EVEN);
            double pct = totalSpent.compareTo(BigDecimal.ZERO) > 0
                    ? amt.divide(totalSpent, 4, RoundingMode.HALF_EVEN).doubleValue() * 100.0
                    : 0.0;

            String name = getCategoryDisplayName(entry.getKey());
            if (amt.compareTo(maxSpent) > 0)
            {
                maxSpent = amt;
                topCat = name;
            }

            categories.add(new CategorySpending(
                    entry.getKey(),
                    name,
                    amt,
                    Math.round(pct * 10.0) / 10.0,
                    categoryCounts.get(entry.getKey())
            ));
        }

        // Sort descending by amount
        categories.sort((a, b) -> b.amount().compareTo(a.amount()));

        return new SpendingAnalyticsResponse(
                accountId,
                account.getMoneda(),
                yearMonth.toString(),
                totalSpent.setScale(2, RoundingMode.HALF_EVEN),
                count,
                topCat,
                categories
        );
    }

    public static String categorize(String reason, String counterpartyIban)
    {
        if (reason == null) reason = "";
        String text = (reason + " " + counterpartyIban).toLowerCase();

        if (text.contains("mega") || text.contains("lidl") || text.contains("kaufland") || text.contains("carrefour")
                || text.contains("auchan") || text.contains("profi") || text.contains("alimente") || text.contains("piata") || text.contains("supermarket"))
        {
            return "ALIMENTE";
        }
        if (text.contains("factur") || text.contains("enel") || text.contains("digi") || text.contains("orange")
                || text.contains("vodafone") || text.contains("electrica") || text.contains("gaz") || text.contains("eon") || text.contains("intretinere"))
        {
            return "UTILITATI";
        }
        if (text.contains("glovo") || text.contains("bolt food") || text.contains("tazz") || text.contains("restaurant")
                || text.contains("cafe") || text.contains("bar") || text.contains("pizza") || text.contains("burger") || text.contains("kfc") || text.contains("mcdonald"))
        {
            return "RESTAURANTE";
        }
        if (text.contains("uber") || text.contains("bolt") || text.contains("omv") || text.contains("rompetrol")
                || text.contains("petrom") || text.contains("mol") || text.contains("metrorex") || text.contains("cfr") || text.contains("benzina") || text.contains("parcare"))
        {
            return "TRANSPORT";
        }
        if (text.contains("netflix") || text.contains("spotify") || text.contains("cinema") || text.contains("steam")
                || text.contains("teatru") || text.contains("bilete") || text.contains("concert") || text.contains("joc"))
        {
            return "DIVERTISMENT";
        }
        return "ALTELE";
    }

    private String getCategoryDisplayName(String key)
    {
        return switch (key) {
            case "ALIMENTE" -> "Alimente & Supermarket";
            case "UTILITATI" -> "Facturi & Utilități";
            case "RESTAURANTE" -> "Restaurante & Cafenele";
            case "TRANSPORT" -> "Transport & Combustibil";
            case "DIVERTISMENT" -> "Divertisment & Servicii";
            default -> "Transferuri & Altele";
        };
    }
}
