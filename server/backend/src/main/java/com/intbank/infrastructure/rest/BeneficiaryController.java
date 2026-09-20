package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.BeneficiaryJpaEntity;
import com.intbank.infrastructure.persistence.repository.BeneficiaryJpaRepository;
import com.intbank.service.AuditLogService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/beneficiaries")
public class BeneficiaryController
{

    private final BeneficiaryJpaRepository beneficiaryRepo;
    private final AuditLogService auditLogService;

    public BeneficiaryController(BeneficiaryJpaRepository beneficiaryRepo, AuditLogService auditLogService)
    {
        this.beneficiaryRepo = beneficiaryRepo;
        this.auditLogService = auditLogService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getBeneficiaries(@PathVariable("userId") Long userId)
    {
        List<BeneficiaryJpaEntity> list = beneficiaryRepo.findByUserIdOrderByNameAsc(userId);
        return ResponseEntity.ok(Map.of("beneficiaries", list));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> addBeneficiary(
            @PathVariable("userId") Long userId,
            @RequestBody Map<String, String> body)
    {
        String name = body.get("name");
        String iban = body.get("iban");
        String bankName = body.get("bankName");
        String nickname = body.get("nickname");

        if (name == null || name.isBlank() || iban == null || iban.isBlank())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Numele și IBAN-ul sunt obligatorii"));
        }

        String cleanIban = iban.replaceAll("\\s+", "").toUpperCase();

        var existing = beneficiaryRepo.findByUserIdAndIban(userId, cleanIban);
        if (existing.isPresent())
        {
            BeneficiaryJpaEntity b = existing.get();
            b.setName(name.trim());
            b.setBankName(bankName);
            b.setNickname(nickname);
            beneficiaryRepo.save(b);
            return ResponseEntity.ok(Map.of("success", true, "beneficiary", b));
        }

        BeneficiaryJpaEntity b = new BeneficiaryJpaEntity();
        b.setUserId(userId);
        b.setName(name.trim());
        b.setIban(cleanIban);
        b.setBankName(bankName != null ? bankName : extractBankName(cleanIban));
        b.setNickname(nickname);

        beneficiaryRepo.save(b);
        auditLogService.log(userId, "BENEFICIARY_ADDED", "Added beneficiary " + name + " (" + cleanIban + ")", "127.0.0.1");

        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("success", true, "beneficiary", b));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteBeneficiary(
            @PathVariable("userId") Long userId,
            @PathVariable("id") Long id)
    {
        var opt = beneficiaryRepo.findById(id).filter(b -> b.getUserId().equals(userId));
        if (opt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Beneficiar inexistent"));
        }
        beneficiaryRepo.delete(opt.get());
        auditLogService.log(userId, "BENEFICIARY_DELETED", "Deleted beneficiary ID " + id, "127.0.0.1");
        return ResponseEntity.ok(Map.of("success", true));
    }

    private String extractBankName(String iban)
    {
        if (iban.length() >= 8)
        {
            String code = iban.substring(4, 8).toUpperCase();
            return switch (code) {
                case "BTRL" -> "Banca Transilvania";
                case "RNCB" -> "BCR";
                case "INGB" -> "ING Bank";
                case "BRDE" -> "BRD Societe Generale";
                case "RZBR" -> "Raiffeisen Bank";
                case "CECE" -> "CEC Bank";
                case "BREL" -> "Libra Internet Bank";
                case "INTB" -> "INTBank";
                default -> "Banca din România";
            };
        }
        return "Banca";
    }
}
