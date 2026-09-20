package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
public class Iso20022Service
{

    private static final Logger log = LoggerFactory.getLogger(Iso20022Service.class);
    private static final String INT_BANK_BIC = "INTBROBUXXX";

    /**
     * Generates a standard ISO 20022 pacs.008.001.10 Customer Credit Transfer message.
     */
    public String generatePacs008(String messageId, String endToEndId, String debtorName, String debtorIban,
                                  String creditorName, String creditorIban, BigDecimal amount, String currency, String reason)
    {
        String timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now());
        String msg = """
                <?xml version="1.0" encoding="UTF-8"?>
                <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
                    <FIToFICstmrCdtTrf>
                        <GrpHdr>
                            <MsgId>%s</MsgId>
                            <CreDtTm>%s</CreDtTm>
                            <NbOfTxs>1</NbOfTxs>
                            <SttlmInf>
                                <SttlmMtd>CLRG</SttlmMtd>
                            </SttlmInf>
                        </GrpHdr>
                        <CdtTrfTxInf>
                            <PmtId>
                                <EndToEndId>%s</EndToEndId>
                                <TxId>%s</TxId>
                            </PmtId>
                            <IntrBkSttlmAmt Ccy="%s">%s</IntrBkSttlmAmt>
                            <Dbtr>
                                <Nm>%s</Nm>
                            </Dbtr>
                            <DbtrAcct>
                                <Id>
                                    <IBAN>%s</IBAN>
                                </Id>
                            </DbtrAcct>
                            <DbtrAgt>
                                <FinInstnId>
                                    <BICFI>%s</BICFI>
                                </FinInstnId>
                            </DbtrAgt>
                            <CdtrAgt>
                                <FinInstnId>
                                    <BICFI>%s</BICFI>
                                </FinInstnId>
                            </CdtrAgt>
                            <Cdtr>
                                <Nm>%s</Nm>
                            </Cdtr>
                            <CdtrAcct>
                                <Id>
                                    <IBAN>%s</IBAN>
                                </Id>
                            </CdtrAcct>
                            <RmtInf>
                                <Ustrd>%s</Ustrd>
                            </RmtInf>
                        </CdtTrfTxInf>
                    </FIToFICstmrCdtTrf>
                </Document>
                """.formatted(
                messageId, timestamp, endToEndId, messageId, currency,
                (amount != null ? amount.setScale(2, java.math.RoundingMode.HALF_UP).toPlainString() : "0.00"),
                debtorName, debtorIban, INT_BANK_BIC, extractBicFromIban(creditorIban),
                creditorName, creditorIban, reason
        );

        log.debug("Generated ISO 20022 pacs.008 message for TxId {}", endToEndId);
        return msg;
    }

    /**
     * Generates a standard ISO 20022 pacs.002.001.12 Payment Status Report.
     */
    public String generatePacs002(String originalMessageId, String originalEndToEndId, String statusCode, String reasonDesc)
    {
        String timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now());
        return """
                <?xml version="1.0" encoding="UTF-8"?>
                <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.12">
                    <FIToFIPmtStsRpt>
                        <GrpHdr>
                            <MsgId>%s</MsgId>
                            <CreDtTm>%s</CreDtTm>
                        </GrpHdr>
                        <TxInfAndSts>
                            <OrgnlEndToEndId>%s</OrgnlEndToEndId>
                            <TxSts>%s</TxSts>
                            <StsRsnInf>
                                <Rsn>
                                    <Prtry>%s</Prtry>
                                </Rsn>
                            </StsRsnInf>
                        </TxInfAndSts>
                    </FIToFIPmtStsRpt>
                </Document>
                """.formatted(
                "pacs002-" + UUID.randomUUID(), timestamp, originalEndToEndId, statusCode, reasonDesc
        );
    }

    private String extractBicFromIban(String iban)
    {
        if (iban != null && iban.length() >= 8)
        {
            String bankCode = iban.substring(4, 8);
            return bankCode + "ROBUXXX";
        }
        return "UNKNOWNXXX";
    }
}
