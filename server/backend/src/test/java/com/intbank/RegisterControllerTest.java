package com.intbank;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.rest.RegisterController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class RegisterControllerTest
{

    @Mock
    private UserJpaRepository userRepo;

    private RegisterController registerController;

    // Valid Romanian CNP: 5000101123457 (Sum = 117, 117 % 11 = 7)
    private static final String VALID_CNP = "5000101123457";

    @BeforeEach
    void setUp()
    {
        registerController = new RegisterController(userRepo);
    }

    @Test
    void register_WithEnglishKeys_SucceedsAndReturnsUserId()
    {
        when(userRepo.save(any(UserJpaEntity.class))).thenAnswer(invocation -> {
            UserJpaEntity entity = invocation.getArgument(0);
            entity.setId(101L);
            return entity;
        });

        Map<String, Object> payload = Map.of(
                "firstName", "Ion",
                "lastName", "Popescu",
                "phone", "+40712345678",
                "email", "ion.popescu@example.com",
                "cnp", VALID_CNP,
                "gender", "Masculin",
                "dateOfBirth", "2000-01-01"
        );

        ResponseEntity<Map<String, Object>> response = registerController.register(payload);

        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertTrue((Boolean) response.getBody().get("success"));
        assertEquals(101L, response.getBody().get("userId"));
        verify(userRepo).save(any(UserJpaEntity.class));
    }

    @Test
    void register_WithInvalidCnp_ReturnsBadRequest()
    {
        Map<String, Object> payload = Map.of(
                "firstName", "Ion",
                "lastName", "Popescu",
                "phone", "+40712345678",
                "email", "ion.popescu@example.com",
                "cnp", "1234567890123", // Invalid checksum
                "gender", "Masculin",
                "dateOfBirth", "2000-01-01"
        );

        ResponseEntity<Map<String, Object>> response = registerController.register(payload);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().get("error").toString().contains("CNP"));
        verify(userRepo, never()).save(any());
    }

    @Test
    void register_WithMissingFields_ReturnsBadRequest()
    {
        Map<String, Object> payload = Map.of(
                "firstName", "Ion",
                "email", "ion@example.com"
        );

        ResponseEntity<Map<String, Object>> response = registerController.register(payload);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(userRepo, never()).save(any());
    }
}
