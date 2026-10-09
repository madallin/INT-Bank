package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.CardJpaEntity;
import com.intbank.infrastructure.persistence.repository.CardJpaRepository;
import com.intbank.service.AuditLogService;
import com.intbank.service.CryptoService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/users/{userId}/cards")
public class CardController
{

    static final BigDecimal MAX_SPENDING_LIMIT = new BigDecimal("100000.00");

    private final CardJpaRepository cardRepo;
    private final CryptoService cryptoService;
    private final AuditLogService auditLogService;
    private final com.intbank.service.NotificationService notificationService;
    private final com.intbank.infrastructure.security.SecurityGuard securityGuard;

    public CardController(CardJpaRepository cardRepo, CryptoService cryptoService, AuditLogService auditLogService, com.intbank.service.NotificationService notificationService)
    {
        this(cardRepo, cryptoService, auditLogService, notificationService, null);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public CardController(CardJpaRepository cardRepo, CryptoService cryptoService, AuditLogService auditLogService, com.intbank.service.NotificationService notificationService,
                          @org.springframework.beans.factory.annotation.Autowired(required = false) com.intbank.infrastructure.security.SecurityGuard securityGuard)
    {
        this.cardRepo = cardRepo;
        this.cryptoService = cryptoService;
        this.auditLogService = auditLogService;
        this.notificationService = notificationService;
        this.securityGuard = securityGuard;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getCards(@PathVariable("userId") Long userId)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
        List<CardJpaEntity> cards = cardRepo.findByUser_Id(userId);
        var mapped = cards.stream().map(this::toMap).toList();
        return ResponseEntity.ok(Map.of("cards", mapped));
    }

    @GetMapping("/{cardId}")
    public ResponseEntity<Map<String, Object>> getCard(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
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
        return setFrozen(userId, cardId, true);
    }

    @PutMapping("/{cardId}/unfreeze")
    public ResponseEntity<Map<String, Object>> unfreezeCard(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId)
    {
        return setFrozen(userId, cardId, false);
    }

    private ResponseEntity<Map<String, Object>> setFrozen(Long userId, Long cardId, boolean frozen)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
        var cardOpt = cardRepo.findById(cardId).filter(c -> c.getUserId() != null && c.getUserId().equals(userId));
        if (cardOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent"));
        }
        CardJpaEntity card = cardOpt.get();
        String target = frozen ? CardJpaEntity.STATUS_FROZEN : CardJpaEntity.STATUS_ACTIVE;
        if (!target.equals(card.getStatus()))
        {
            card.setStatus(target);
            card.setStatusChangedAt(Instant.now());
            cardRepo.save(card);
            if (frozen)
            {
                auditLogService.log(userId, "CARD_FROZEN", "Card ID " + cardId + " frozen by user", "127.0.0.1");
                notificationService.notify(userId, "Alertă de securitate: Card blocat", "Cardul tău INTBank a fost blocat temporar din aplicație.", "SECURITY_ALERT");
            }
            else
            {
                auditLogService.log(userId, "CARD_UNFROZEN", "Card ID " + cardId + " unfrozen by user", "127.0.0.1");
                notificationService.notify(userId, "Card deblocat cu succes", "Cardul tău INTBank este acum activ pentru plăți.", "SECURITY_ALERT");
            }
        }
        Map<String, Object> body = new LinkedHashMap<>(toMap(card));
        body.put("success", true);
        body.put("cardId", cardId);
        return ResponseEntity.ok(body);
    }

    @PutMapping("/{cardId}/limits")
    public ResponseEntity<Map<String, Object>> updateCardLimits(
            @PathVariable("userId") Long userId,
            @PathVariable("cardId") Long cardId,
            @RequestBody Map<String, Object> body)
    {
        if (securityGuard != null && !securityGuard.isSelfOrAdmin(userId))
        {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Acces interzis"));
        }
        var cardOpt = cardRepo.findById(cardId).filter(c -> c.getUserId() != null && c.getUserId().equals(userId));
        if (cardOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Card inexistent"));
        }
        CardJpaEntity card = cardOpt.get();

        Object rawLimit = body.get("spendingLimit");
        Object rawOnline = body.get("onlinePayments");
        Object rawContactless = body.get("contactless");
        if ((rawOnline != null && !(rawOnline instanceof Boolean))
                || (rawContactless != null && !(rawContactless instanceof Boolean)))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "Opțiuni de plată invalide"));
        }
        BigDecimal newLimit = card.getSpendingLimit();
        if (rawLimit != null)
        {
            try
            {
                newLimit = new BigDecimal(rawLimit.toString()).setScale(2, RoundingMode.HALF_EVEN);
            }
            catch (NumberFormatException e)
            {
                newLimit = null;
            }
            if (newLimit == null || newLimit.signum() <= 0 || newLimit.compareTo(MAX_SPENDING_LIMIT) > 0)
            {
                return ResponseEntity.badRequest().body(Map.of("error",
                        "Limita trebuie să fie între 1 și " + MAX_SPENDING_LIMIT.toPlainString()));
            }
        }

        card.setSpendingLimit(newLimit);
        if (rawOnline != null) card.setOnlinePaymentsEnabled((Boolean) rawOnline);
        if (rawContactless != null) card.setContactlessEnabled((Boolean) rawContactless);
        cardRepo.save(card);

        auditLogService.log(userId, "CARD_LIMIT_CHANGED", "Card ID " + cardId + " new limit: " + card.getSpendingLimit()
                + ", online: " + card.isOnlinePaymentsEnabled() + ", contactless: " + card.isContactlessEnabled(), "127.0.0.1");
        notificationService.notify(userId, "Setări card actualizate", "Setările și limitele cardului au fost actualizate.", "SECURITY_ALERT");

        Map<String, Object> response = new LinkedHashMap<>(toMap(card));
        response.put("success", true);
        response.put("cardId", cardId);
        return ResponseEntity.ok(response);
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

        String rawCard = decryptedCard != null ? decryptedCard : "4999999999999999";
        String maskedCard = rawCard.length() >= 4
                ? "•••• •••• •••• " + rawCard.substring(rawCard.length() - 4)
                : "•••• •••• •••• ••••";

        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", c.getId());
        map.put("accountId", c.getAccountId());
        map.put("cardNumber", maskedCard);
        map.put("cardHolder", c.getDetinator());
        map.put("expiryDate", decryptedExpiry != null ? decryptedExpiry : "12/28");
        map.put("cvv", "***"); // Masked for PCI-DSS compliance
        map.put("cardType", "Visa Classic");
        map.put("token", c.getToken());
        map.put("status", c.isFrozen() ? "frozen" : "active");
        map.put("isBlocked", c.isFrozen());
        map.put("spendingLimit", c.getSpendingLimit());
        map.put("onlinePayments", c.isOnlinePaymentsEnabled());
        map.put("contactless", c.isContactlessEnabled());
        return map;
    }
}
