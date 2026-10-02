package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@RestController
@RequestMapping("/register")
public class RegisterController
{

    private static final Logger log = LoggerFactory.getLogger(RegisterController.class);
    private final UserJpaRepository userRepo;

    public RegisterController(UserJpaRepository userRepo)
    {
        this.userRepo = userRepo;
    }

    private static final int[] CNP_WEIGHTS = {2, 7, 9, 1, 4, 6, 3, 5, 8, 2, 7, 9};

    @PostMapping
    @Transactional
    public ResponseEntity<Map<String, Object>> register(@RequestBody Map<String, Object> body)
    {
        String nume = (String) body.getOrDefault("nume", body.get("lastName"));
        String prenume = (String) body.getOrDefault("prenume", body.get("firstName"));
        String email = (String) body.get("email");
        String nrtelefon = (String) body.getOrDefault("nrtelefon", body.get("phone"));
        String sex = (String) body.getOrDefault("sex", body.get("gender"));
        String datanasterii = (String) body.getOrDefault("datanasterii", body.get("dateOfBirth"));
        String cnp = (String) body.get("cnp");

        if (nume == null || prenume == null || email == null || nrtelefon == null
                || sex == null || datanasterii == null || cnp == null
                || nume.isBlank() || prenume.isBlank() || email.isBlank()
                || nrtelefon.isBlank() || cnp.isBlank())
        {
            return ResponseEntity.badRequest().body(Map.of("statusCode", 400, "error", "Toate campurile sunt obligatorii"));
        }

        // Clean CNP
        cnp = cnp.replaceAll("\\s+", "");
        if (!isValidCnp(cnp))
        {
            return ResponseEntity.badRequest().body(Map.of("statusCode", 400, "error", "CNP invalid. Trebuie sa aiba 13 cifre si un format valid."));
        }

        String strada = (String) body.get("strada");
        String numar = (String) body.get("numar");
        String bloc = (String) body.get("bloc");
        String scara = (String) body.get("scara");
        String apartament = (String) body.get("apartament");

        String adresa = Stream.of(
                strada,
                numar != null ? "Nr. " + numar : "",
                bloc != null ? "Bl. " + bloc : "",
                scara != null ? "Sc. " + scara : "",
                apartament != null ? "Ap. " + apartament : ""
        ).filter(s -> s != null && !s.isEmpty()).collect(Collectors.joining(", "));

        try
        {
            UserJpaEntity user = new UserJpaEntity();
            user.setNume(nume.trim());
            user.setPrenume(prenume.trim());
            user.setEmail(email.trim().toLowerCase());
            user.setNrTelefon(nrtelefon.trim());
            user.setSex(sex.trim());
            user.setDataNasterii(LocalDate.parse(datanasterii.trim()));
            user.setCnp(cnp);
            user.setJudet((String) body.get("judet"));
            user.setLocalitate((String) body.get("localitate"));
            user.setAdresa(adresa);
            user.setCodPostal((String) body.get("codPostal"));
            user.setPlaceId((String) body.get("placeId"));
            user.setLat(body.get("lat") != null ? ((Number) body.get("lat")).doubleValue() : null);
            user.setLng(body.get("lng") != null ? ((Number) body.get("lng")).doubleValue() : null);
            user.setBloc(bloc);
            user.setScara(scara);
            user.setApartament(apartament);

            userRepo.save(user);
            log.info("User registered: id={}", user.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                    "success", true,
                    "userId", user.getId(),
                    "user", Map.of("id", user.getId())
            ));
        }
        catch (Exception err)
        {
            log.error("Eroare la baza de date (register)", err);
            if (err.getMessage() != null && err.getMessage().contains("duplicate"))
            {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(Map.of("statusCode", 409, "error", "Email, telefon sau CNP deja existent"));
            }
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("statusCode", 500, "error", "Eroare la comunicarea cu serverul"));
        }
    }

    private boolean isValidCnp(String cnp)
    {
        if (cnp == null || !cnp.matches("^\\d{13}$"))
        {
            return false;
        }
        int sum = 0;
        for (int i = 0; i < 12; i++)
        {
            sum += Character.getNumericValue(cnp.charAt(i)) * CNP_WEIGHTS[i];
        }
        int remainder = sum % 11;
        int checkDigit = remainder == 10 ? 1 : remainder;
        return checkDigit == Character.getNumericValue(cnp.charAt(12));
    }
}