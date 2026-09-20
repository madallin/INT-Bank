package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.AuditLogJpaEntity;
import com.intbank.infrastructure.persistence.repository.AuditLogJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;

@Service
public class AuditLogService
{

    private static final Logger log = LoggerFactory.getLogger(AuditLogService.class);
    private static final String GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000";

    private final AuditLogJpaRepository auditRepo;

    public AuditLogService(AuditLogJpaRepository auditRepo)
    {
        this.auditRepo = auditRepo;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public synchronized void log(Long userId, String action, String details, String ipAddress)
    {
        try
        {
            String previousHash = auditRepo.findTopByOrderByIdDesc()
                    .map(AuditLogJpaEntity::getCurrentHash)
                    .orElse(GENESIS_HASH);

            Instant now = Instant.now();
            String payload = previousHash + "|" + (userId != null ? userId : "SYSTEM") + "|" + action + "|" + details + "|" + now.toEpochMilli();
            String currentHash = computeSha256(payload);

            AuditLogJpaEntity entry = new AuditLogJpaEntity();
            entry.setUserId(userId);
            entry.setAction(action);
            entry.setDetails(details);
            entry.setIpAddress(ipAddress != null ? ipAddress : "127.0.0.1");
            entry.setPreviousHash(previousHash);
            entry.setCurrentHash(currentHash);
            entry.setCreatedAt(now);

            auditRepo.save(entry);
            log.info("Audit log written: action={}, user={}, hash={}", action, userId, currentHash.substring(0, 12));
        }
        catch (Exception e)
        {
            log.error("Failed to write tamper-evident audit log", e);
        }
    }

    @Transactional(readOnly = true)
    public boolean verifyAuditIntegrity()
    {
        List<AuditLogJpaEntity> chain = auditRepo.findAllByOrderByIdAsc();
        String expectedPrev = GENESIS_HASH;

        for (AuditLogJpaEntity entry : chain)
        {
            if (!entry.getPreviousHash().equals(expectedPrev))
            {
                log.error("Audit chain broken at id {}: previous hash mismatch", entry.getId());
                return false;
            }

            String payload = expectedPrev + "|" + (entry.getUserId() != null ? entry.getUserId() : "SYSTEM")
                    + "|" + entry.getAction() + "|" + entry.getDetails() + "|" + entry.getCreatedAt().toEpochMilli();
            String recomputed = computeSha256(payload);

            if (!recomputed.equals(entry.getCurrentHash()))
            {
                log.error("Audit content tampered at id {}: content hash mismatch", entry.getId());
                return false;
            }

            expectedPrev = entry.getCurrentHash();
        }

        return true;
    }

    private String computeSha256(String input)
    {
        try
        {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        }
        catch (Exception e)
        {
            throw new RuntimeException("SHA-256 computation failed", e);
        }
    }
}
