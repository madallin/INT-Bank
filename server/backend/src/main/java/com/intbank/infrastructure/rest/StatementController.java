package com.intbank.infrastructure.rest;

import com.intbank.service.StatementService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/accounts/{accountId}/statement")
public class StatementController
{

    private final StatementService statementService;

    public StatementController(StatementService statementService)
    {
        this.statementService = statementService;
    }

    @GetMapping
    public ResponseEntity<?> getStatement(
            @PathVariable("userId") Long userId,
            @PathVariable("accountId") Long accountId,
            @RequestParam(value = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(value = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate)
    {
        LocalDate to = toDate != null ? toDate : LocalDate.now();
        LocalDate from = fromDate != null ? fromDate : to.minusDays(30);

        try
        {
            var statement = statementService.getStatement(userId, accountId, from, to);
            return ResponseEntity.ok(statement);
        }
        catch (IllegalArgumentException e)
        {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/pdf")
    public ResponseEntity<?> downloadStatementPdf(
            @PathVariable("userId") Long userId,
            @PathVariable("accountId") Long accountId,
            @RequestParam(value = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(value = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate)
    {
        LocalDate to = toDate != null ? toDate : LocalDate.now();
        LocalDate from = fromDate != null ? fromDate : to.minusDays(30);

        try
        {
            byte[] pdfBytes = statementService.generateStatementPdf(userId, accountId, from, to);
            String filename = "extras_cont_" + from + "_" + to + ".pdf";

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                    .contentType(MediaType.APPLICATION_PDF)
                    .contentLength(pdfBytes.length)
                    .body(pdfBytes);
        }
        catch (IllegalArgumentException e)
        {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
