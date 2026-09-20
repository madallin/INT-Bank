package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.websocket.ApprovalWebSocketHandler;
import com.intbank.service.BankingService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/users")
public class UserController
{

    private static final Logger log = LoggerFactory.getLogger(UserController.class);

    private final UserJpaRepository userRepo;
    private final BankingService bankingService;
    private final PasswordEncoder passwordEncoder;

    public UserController(UserJpaRepository userRepo,
                          BankingService bankingService,
                          PasswordEncoder passwordEncoder)
    {
        this.userRepo = userRepo;
        this.bankingService = bankingService;
        this.passwordEncoder = passwordEncoder;
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getUserProfile(@PathVariable("id") Long id)
    {
        return userRepo.findById(id)
                .map(user -> {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("id", user.getId());
                    map.put("nume", user.getNume());
                    map.put("prenume", user.getPrenume());
                    map.put("email", user.getEmail());
                    map.put("nrTelefon", user.getNrTelefon());
                    map.put("sex", user.getSex());
                    map.put("dataNasterii", user.getDataNasterii() != null ? user.getDataNasterii().toString() : null);
                    map.put("cnp", user.getCnp());
                    map.put("judet", user.getJudet());
                    map.put("localitate", user.getLocalitate());
                    map.put("adresa", user.getAdresa());
                    map.put("codPostal", user.getCodPostal());
                    map.put("contAprobat", Boolean.TRUE.equals(user.getContAprobat()));
                    map.put("termeniAcceptati", Boolean.TRUE.equals(user.getTermeniAcceptati()));
                    map.put("hasPin", user.getCodPin() != null && !user.getCodPin().isBlank());
                    return ResponseEntity.ok(map);
                })
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent")));
    }

    @GetMapping("/{id}/has-tos")
    public ResponseEntity<Map<String, Object>> hasTos(@PathVariable("id") Long id)
    {
        return userRepo.findById(id)
                .map(u -> ResponseEntity.ok(Map.<String, Object>of("termeniAcceptati", Boolean.TRUE.equals(u.getTermeniAcceptati()))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent")));
    }

    @RequestMapping(value = "/{id}/accept-tos", method = {RequestMethod.PUT, RequestMethod.POST})
    @Transactional
    public ResponseEntity<Map<String, Object>> acceptTos(@PathVariable("id") Long id)
    {
        var userOpt = userRepo.findById(id);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent"));
        }
        UserJpaEntity user = userOpt.get();
        user.setTermeniAcceptati(true);
        userRepo.save(user);
        return ResponseEntity.ok(Map.of("success", true, "termeniAcceptati", true));
    }

    @GetMapping("/{id}/has-approved")
    public ResponseEntity<Map<String, Object>> hasApproved(@PathVariable("id") Long id)
    {
        return userRepo.findById(id)
                .map(u -> ResponseEntity.ok(Map.<String, Object>of("contaprobat", Boolean.TRUE.equals(u.getContAprobat()))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent")));
    }

    @PostMapping("/{id}/approve")
    @Transactional
    public ResponseEntity<Map<String, Object>> approveUser(@PathVariable("id") Long id)
    {
        var userOpt = userRepo.findById(id);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent"));
        }
        UserJpaEntity user = userOpt.get();
        user.setContAprobat(true);
        userRepo.save(user);

        // If user doesn't have an account yet, automatically provision one with card
        if (user.getAccounts() == null || user.getAccounts().isEmpty())
        {
            try
            {
                bankingService.createAccountAndCardWithRetry(id, "RON", "RO");
                log.info("Auto-provisioned account and card for approved user {}", id);
            }
            catch (Exception e)
            {
                log.error("Failed to auto-provision account for approved user {}", id, e);
            }
        }

        // Broadcast approval via WebSocket to notify client in real time
        ApprovalWebSocketHandler.broadcast("{\"type\":\"contAprobat\",\"id\":" + id + ",\"status\":\"approved\"}");

        return ResponseEntity.ok(Map.of("success", true, "contAprobat", true));
    }

    @GetMapping("/{id}/has-pin")
    public ResponseEntity<Map<String, Object>> hasPin(@PathVariable("id") Long id)
    {
        return userRepo.findById(id)
                .map(u -> ResponseEntity.ok(Map.<String, Object>of("hasPin", u.getCodPin() != null && !u.getCodPin().isBlank())))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent")));
    }

    @RequestMapping(value = "/{id}/set-pin", method = {RequestMethod.PUT, RequestMethod.POST})
    @Transactional
    public ResponseEntity<Map<String, Object>> setPin(@PathVariable("id") Long id, @RequestBody Map<String, String> body)
    {
        String pin = body.get("codPin");
        if (pin == null || pin.isBlank())
        {
            pin = body.get("pin");
        }
        if (pin == null || pin.length() < 4 || pin.length() > 6 || !pin.matches("\\d+"))
        {
            return ResponseEntity.badRequest().body(Map.of("error", "PIN invalid. Trebuie sa contina 4-6 cifre."));
        }

        var userOpt = userRepo.findById(id);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent"));
        }

        UserJpaEntity user = userOpt.get();
        user.setCodPin(passwordEncoder.encode(pin));
        user.setPinFailedAttempts(0);
        user.setPinLockedUntil(null);
        userRepo.save(user);

        return ResponseEntity.ok(Map.of("success", true, "message", "PIN setat cu succes"));
    }

    @PostMapping("/{id}/verify-pin")
    @Transactional
    public ResponseEntity<Map<String, Object>> verifyPin(@PathVariable("id") Long id, @RequestBody Map<String, String> body)
    {
        String pin = body.get("pin");
        if (pin == null || pin.isBlank())
        {
            return ResponseEntity.badRequest().body(Map.of("error", "PIN lipsa"));
        }

        var userOpt = userRepo.findById(id);
        if (userOpt.isEmpty())
        {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Utilizator inexistent"));
        }

        UserJpaEntity user = userOpt.get();

        if (user.getPinLockedUntil() != null && user.getPinLockedUntil().isAfter(Instant.now()))
        {
            long remaining = java.time.Duration.between(Instant.now(), user.getPinLockedUntil()).toMinutes() + 1;
            return ResponseEntity.status(HttpStatus.LOCKED)
                    .body(Map.of("success", false, "error", "Cont blocat temporar. Reincearca in " + remaining + " minute."));
        }

        if (user.getCodPin() == null || !passwordEncoder.matches(pin, user.getCodPin()))
        {
            int attempts = user.getPinFailedAttempts() + 1;
            user.setPinFailedAttempts(attempts);
            if (attempts >= 3)
            {
                user.setPinLockedUntil(Instant.now().plus(java.time.Duration.ofMinutes(15)));
                user.setPinFailedAttempts(0);
            }
            userRepo.save(user);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("success", false, "error", "PIN incorect", "remainingAttempts", Math.max(0, 3 - attempts)));
        }

        user.setPinFailedAttempts(0);
        user.setPinLockedUntil(null);
        userRepo.save(user);

        return ResponseEntity.ok(Map.of("success", true));
    }
}
