package com.intbank.infrastructure.rest;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
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

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> register(@RequestBody Map<String, Object> body)
    {
        String nume = (String) body.get("nume");
        String prenume = (String) body.get("prenume");
        String email = (String) body.get("email");
        String nrtelefon = (String) body.get("nrtelefon");
        String sex = (String) body.get("sex");
        String datanasterii = (String) body.get("datanasterii");
        String cnp = (String) body.get("cnp");

        if (nume == null || prenume == null || email == null || nrtelefon == null
                || sex == null || datanasterii == null || cnp == null)
        {
            return Map.of("statusCode", 400, "error", "Toate campurile sunt obligatorii");
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
        ).filter(s -> !s.isEmpty()).collect(Collectors.joining(", "));

        try
        {
            UserJpaEntity user = new UserJpaEntity();
            user.setNume(nume);
            user.setPrenume(prenume);
            user.setEmail(email);
            user.setNrTelefon(nrtelefon);
            user.setSex(sex);
            user.setDataNasterii(LocalDate.parse(datanasterii));
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
            return Map.of("success", true, "user", Map.of("id", user.getId()));
        }
        catch (Exception err)
        {
            log.error("Eroare la baza de date (register)", err);
            if (err.getMessage() != null && err.getMessage().contains("duplicate"))
            {
                return Map.of("statusCode", 400, "error", "Email sau CNP deja existent");
            }
            return Map.of("statusCode", 500, "error", "Eroare la comunicarea cu serverul");
        }
    }
}