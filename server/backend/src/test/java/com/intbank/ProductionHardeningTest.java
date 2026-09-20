package com.intbank;

import com.intbank.infrastructure.rest.JwksController;
import com.intbank.infrastructure.security.RsaKeyProvider;
import com.intbank.service.Iso20022Service;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

public class ProductionHardeningTest
{

    @Test
    void testRsaKeyProviderAndJwks_ReturnsValidRsaJwk()
    {
        RsaKeyProvider keyProvider = new RsaKeyProvider();
        assertNotNull(keyProvider.getPrivateKey());
        assertNotNull(keyProvider.getPublicKey());

        JwksController controller = new JwksController(keyProvider);
        var response = controller.getJwks();

        assertNotNull(response.getBody());
        List<?> keys = (List<?>) response.getBody().get("keys");
        assertFalse(keys.isEmpty());

        Map<?, ?> firstKey = (Map<?, ?>) keys.get(0);
        assertEquals("RSA", firstKey.get("kty"));
        assertEquals("RS256", firstKey.get("alg"));
        assertEquals(RsaKeyProvider.KEY_ID, firstKey.get("kid"));
        assertNotNull(firstKey.get("n"));
        assertNotNull(firstKey.get("e"));
    }

    @Test
    void testIso20022Service_GeneratesValidPacs008Xml()
    {
        Iso20022Service isoService = new Iso20022Service();
        String xml = isoService.generatePacs008(
                "msg-100", "e2e-200", "Popescu Ion", "RO49AAAA1B31007593840000",
                "Ionescu Maria", "RO49BTRL1B31007593841111", BigDecimal.valueOf(500.50),
                "RON", "Plata factura"
        );

        assertNotNull(xml);
        assertTrue(xml.contains("urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10"));
        assertTrue(xml.contains("<EndToEndId>e2e-200</EndToEndId>"));
        assertTrue(xml.contains("<IntrBkSttlmAmt Ccy=\"RON\">500.50</IntrBkSttlmAmt>"));
        assertTrue(xml.contains("Popescu Ion"));
        assertTrue(xml.contains("Ionescu Maria"));
    }
}
