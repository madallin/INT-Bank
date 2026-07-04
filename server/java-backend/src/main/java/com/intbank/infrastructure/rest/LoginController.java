package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/login")
public class LoginController
{

    private static final Logger log = LoggerFactory.getLogger(LoginController.class);
    private final UserJpaRepository userRepo;

    public LoginController(UserJpaRepository userRepo)
    {
        this.userRepo = userRepo;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.OK)
    public Map<String, Object> login(@RequestBody Map<String, String> body)
    {
        String phone = body.get("phone");
        if (phone == null || phone.isBlank()) {
            return Map.of("statusCode", 400, "error", "Numar de telefon invalid");
        }

        try {
            var user = userRepo.findByNrTelefon(phone);
            if (user.isEmpty()) {
                return Map.of("exists", false);
            }
            var u = user.get();
            return Map.of(
                    "exists", true,
                    "userId", u.getId(),
                    "approved", u.getContAprobat() != null && u.getContAprobat(),
                    "acceptedterms", u.getTermeniAcceptati() != null && u.getTermeniAcceptati()
            );
        } catch (Exception err) {
            log.error("Eroare la baza de date (login)", err);
            return Map.of("statusCode", 500, "error", "Eroare la comunicarea cu serverul");
        }
    }
}