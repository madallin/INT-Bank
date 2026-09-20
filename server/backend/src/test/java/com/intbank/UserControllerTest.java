package com.intbank;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.UserJpaRepository;
import com.intbank.infrastructure.rest.UserController;
import com.intbank.service.BankingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UserControllerTest
{

    @Mock
    private UserJpaRepository userRepo;

    @Mock
    private BankingService bankingService;

    @Mock
    private PasswordEncoder passwordEncoder;

    private UserController userController;

    @BeforeEach
    void setUp()
    {
        userController = new UserController(userRepo, bankingService, passwordEncoder);
    }

    @Test
    void testSetPin_Valid6DigitPin_Success()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);

        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.encode("123456")).thenReturn("hashed-pin-123456");

        ResponseEntity<Map<String, Object>> response = userController.setPin(1L, Map.of("codPin", "123456"));

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue((Boolean) response.getBody().get("success"));
        assertEquals("hashed-pin-123456", user.getCodPin());
        verify(userRepo).save(user);
    }

    @Test
    void testVerifyPin_CorrectPin_Success()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);
        user.setCodPin("hashed-pin");

        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("123456", "hashed-pin")).thenReturn(true);

        ResponseEntity<Map<String, Object>> response = userController.verifyPin(1L, Map.of("pin", "123456"));

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue((Boolean) response.getBody().get("success"));
    }

    @Test
    void testVerifyPin_WrongPin_IncrementsFailedAttempts()
    {
        UserJpaEntity user = new UserJpaEntity();
        user.setId(1L);
        user.setCodPin("hashed-pin");
        user.setPinFailedAttempts(0);

        when(userRepo.findById(1L)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("000000", "hashed-pin")).thenReturn(false);

        ResponseEntity<Map<String, Object>> response = userController.verifyPin(1L, Map.of("pin", "000000"));

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertFalse((Boolean) response.getBody().get("success"));
        assertEquals(1, user.getPinFailedAttempts());
        verify(userRepo).save(user);
    }
}
