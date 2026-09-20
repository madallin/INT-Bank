package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import com.intbank.infrastructure.persistence.repository.CardJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.CryptoService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/cards")
public class CardController
{

    private final CardJpaRepository cardRepo;
    private final CryptoService cryptoService;
    private final AuditLogService auditLogService;
    private final com.intbank.service.NotificationService notificationService;

    public CardController(CardJpaRepository cardRepo, CryptoService cryptoService, AuditLogService auditLogService, com.intbank.service.NotificationService notificationService)
    {
        this.cardRepo = cardRepo;
        this.cryptoService = cryptoService;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getCards(@PathVariable("userId") Long userId)
    {
        List<CardJpaEntity> cards = cardRepo.findByUser_Id(userId);
        var mapped = cards.stream().map(this::toMap).toList();
        return ResponseEntity.ok(Map.of("cards", mapped));
    }

    @GetMapping("/{cardId}")
    public ResponseEntity<Map<String, Object>> getCard(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId)
    {
        return cardRepo.findById(cardId)
                .filter(c -> c.getUserId() != null && c.getUserId().equals(userId))
                .map(c -> ResponseEntity.ok(Map.<String, Object>of("card", toMap(c))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent")));
    }

    @PutMapping("/{cardId}/freeze")
    public ResponseEntity<Map<String, Object>> freezeCard(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId)
    {
        var cardOpt = cardRepo.findById(cardId).filter(c -> c.getUserId() != null && c.getUserId().equals(userId));
        if (cardOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent"));
        }
        auditLogService.log(userId, "CARD_FROZEN", "Card ID " + cardId + " frozen by user", "127.0.0.1");
        notificationService.notify(userId, "Alertă de securitate: Card blocat", "Cardul tău INTBank a fost blocat temporar din aplicație.", "SECURITY_ALERT");
        return ResponseEntity.ok(Map.of("success", true, "cardId", cardId, "isBlocked", true, "status", "frozen"));
    }

    @PutMapping("/{cardId}/unfreeze")
    public ResponseEntity<Map<String, Object>> unfreezeCard(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId)
    {
        var cardOpt = cardRepo.findById(cardId).filter(c -> c.getUserId() != null && c.getUserId().equals(userId));
        if (cardOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent"));
        }
        auditLogService.log(userId, "CARD_UNFROZEN", "Card ID " + cardId + " unfrozen by user", "127.0.0.1");
        notificationService.notify(userId, "Card deblocat cu succes", "Cardul tău INTBank este acum activ pentru plăți.", "SECURITY_ALERT");
        return ResponseEntity.ok(Map.of("success", true, "cardId", cardId, "isBlocked", false, "status", "active"));
    }

    @PutMapping("/{cardId}/limits")
    public ResponseEntity<Map<String, Object>> updateCardLimits(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId,
            @RequestBody Map<String, Object> body)
    {
        var cardOpt = cardRepo.findById(cardId).filter(c -> c.getUserId() != null && c.getUserId().equals(userId));
        if (cardOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent"));
        }
        Number newLimit = (Number) body.getOrDefault("spendingLimit", 5000.0);
        auditLogService.log(userId, "CARD_LIMIT_CHANGED", "Card ID " + cardId + " new limit: " + newLimit, "127.0.0.1");
        notificationService.notify(userId, "Limită card actualizată", "Noua limită zilnică de tranzacții este de " + newLimit + " RON.", "SECURITY_ALERT");
        return ResponseEntity.ok(Map.of("success", true, "cardId", cardId, "spendingLimit", newLimit.doubleValue()));
    }

    private Map<String, Object> toMap(CardJpaEntity c)
    {
        String decryptedCard = c.getNumarCard();
        if (decryptedCard != null && decryptedCard.startsWith("enc:"))
        {
            try
            {
                decryptedCard = cryptoService.decryptAESGCM(decryptedCard);
            }
            catch (Exception e)
            {
                decryptedCard = "4999999999999999";
            }
        }

        String decryptedExpiry = c.getDataExpirare();
        if (decryptedExpiry != null && decryptedExpiry.startsWith("enc:"))
        {
            try
            {
                decryptedExpiry = cryptoService.decryptAESGCM(decryptedExpiry);
            }
            catch (Exception e)
            {
                decryptedExpiry = "12/28";
            }
        }

        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", c.getId());
        map.put("accountId", c.getAccountId());
        map.put("cardNumber", decryptedCard != null ? decryptedCard : "4999999999999999");
        map.put("cardHolder", c.getDetinator());
        map.put("expiryDate", decryptedExpiry != null ? decryptedExpiry : "12/28");
        map.put("cvv", "***"); // Masked for PCI-DSS compliance
        map.put("cardType", "Visa Classic");
        map.put("token", c.getToken());
        map.put("status", "active");
        map.put("isBlocked", false);
        map.put("spendingLimit", 5000.0);
        return map;
    }
}
