package com.intbank.service;

import com.intbank.infrastructure.persistence.entity.AccountJpaEntity;
import com.intbank.infrastructure.persistence.entity.TransferJpaEntity;
import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import com.intbank.infrastructure.persistence.repository.AccountJpaRepository;
import com.intbank.infrastructure.persistence.repository.TransferJpaRepository;
import com.lowagie.text.*;
import com.lowagie.text.pdf.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.List;

@Service
public class StatementService
{

    private static final Logger log = LoggerFactory.getLogger(StatementService.class);
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd.MM.yyyy");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");

    private final AccountJpaRepository accountRepo;
    private final TransferJpaRepository transferRepo;
    private final AuditLogService auditLogService;

    public StatementService(AccountJpaRepository accountRepo,
                            TransferJpaRepository transferRepo,
                            AuditLogService auditLogService)
    {
        this.accountRepo = accountRepo;
        this.transferRepo = transferRepo;
        this.auditLogService = auditLogService;
    }

    public record StatementItem(
            String id,
            String date,
            String type, // DEBIT or CREDIT
            String partyName,
            String partyIban,
            String description,
            BigDecimal amount,
            String currency
    ) {}

    public record StatementResponse(
            Long accountId,
            String iban,
            String currency,
            String accountHolder,
            String cnp,
            String fromDate,
            String toDate,
            String generatedAt,
            BigDecimal openingBalance,
            BigDecimal totalInflows,
            BigDecimal totalOutflows,
            BigDecimal closingBalance,
            int transactionCount,
            List<StatementItem> transactions
    ) {}

    @Transactional(readOnly = true)
    public StatementResponse getStatement(Long userId, Long accountId, LocalDate fromDate, LocalDate toDate)
    {
        AccountJpaEntity account = validateAndGetAccount(userId, accountId);
        validateDateRange(fromDate, toDate);

        Instant startInstant = fromDate.atStartOfDay(ZoneId.systemDefault()).toInstant();
        Instant endInstant = toDate.atTime(LocalTime.MAX).atZone(ZoneId.systemDefault()).toInstant();

        List<TransferJpaEntity> allTransfers = transferRepo.findAll();

        List<TransferJpaEntity> periodTransfers = new ArrayList<>();
        BigDecimal netChangeAfterPeriod = BigDecimal.ZERO;
        BigDecimal periodInflows = BigDecimal.ZERO;
        BigDecimal periodOutflows = BigDecimal.ZERO;

        for (TransferJpaEntity t : allTransfers)
        {
            boolean isDebit = t.getFromAccount() != null && t.getFromAccount().getId().equals(accountId);
            boolean isCredit = t.getToAccount() != null && t.getToAccount().getId().equals(accountId);

            if (!isDebit && !isCredit) continue;
            if (!"COMPLETED".equalsIgnoreCase(t.getStatus()) && !"PENDING".equalsIgnoreCase(t.getStatus())) continue;

            Instant txTime = t.getInitiatedAt();
            if (txTime == null) continue;

            if (txTime.isAfter(endInstant))
            {
                // Transaction occurred after the requested period
                if (isDebit) netChangeAfterPeriod = netChangeAfterPeriod.subtract(t.getAmount());
                if (isCredit) netChangeAfterPeriod = netChangeAfterPeriod.add(t.getAmount());
            }
            else if (!txTime.isBefore(startInstant))
            {
                // Inside the period
                periodTransfers.add(t);
                if (isDebit) periodOutflows = periodOutflows.add(t.getAmount());
                if (isCredit) periodInflows = periodInflows.add(t.getAmount());
            }
        }

        // Sort period transactions descending by timestamp
        periodTransfers.sort((a, b) -> b.getInitiatedAt().compareTo(a.getInitiatedAt()));

        // Current account sold minus net movements after endInstant equals closing balance at end of period
        BigDecimal currentSold = account.getSold() != null ? account.getSold() : BigDecimal.ZERO;
        BigDecimal closingBalance = currentSold.subtract(netChangeAfterPeriod).setScale(2, RoundingMode.HALF_EVEN);
        BigDecimal openingBalance = closingBalance.subtract(periodInflows).add(periodOutflows).setScale(2, RoundingMode.HALF_EVEN);

        UserJpaEntity user = account.getUser();
        String holderName = user != null ? (user.getNume() + " " + user.getPrenume()) : "Titular Cont";
        String cnp = user != null && user.getCnp() != null ? user.getCnp() : "-";

        List<StatementItem> items = new ArrayList<>();
        for (TransferJpaEntity t : periodTransfers)
        {
            boolean isDebit = t.getFromAccount() != null && t.getFromAccount().getId().equals(accountId);
            String partyName = isDebit
                    ? (t.getToAccount() != null && t.getToAccount().getUser() != null
                    ? t.getToAccount().getUser().getNume() + " " + t.getToAccount().getUser().getPrenume() : "Beneficiar Extern")
                    : (t.getFromAccount() != null && t.getFromAccount().getUser() != null
                    ? t.getFromAccount().getUser().getNume() + " " + t.getFromAccount().getUser().getPrenume() : "Ordonator");

            String partyIban = isDebit
                    ? (t.getToAccount() != null ? t.getToAccount().getIBAN() : "-")
                    : (t.getFromAccount() != null ? t.getFromAccount().getIBAN() : "-");

            LocalDateTime ldt = LocalDateTime.ofInstant(t.getInitiatedAt(), ZoneId.systemDefault());

            items.add(new StatementItem(
                    t.getId(),
                    ldt.format(TIME_FMT),
                    isDebit ? "DEBIT" : "CREDIT",
                    partyName,
                    partyIban,
                    t.getReason() != null ? t.getReason() : "Transfer",
                    t.getAmount().setScale(2, RoundingMode.HALF_EVEN),
                    t.getCurrency() != null ? t.getCurrency() : account.getMoneda()
            ));
        }

        auditLogService.log(userId, "STATEMENT_VIEWED",
                "Statement generated for account " + account.getIBAN() + " (" + fromDate + " -> " + toDate + ")", "127.0.0.1");

        return new StatementResponse(
                accountId,
                account.getIBAN(),
                account.getMoneda(),
                holderName,
                cnp,
                fromDate.format(DATE_FMT),
                toDate.format(DATE_FMT),
                LocalDateTime.now().format(TIME_FMT),
                openingBalance,
                periodInflows.setScale(2, RoundingMode.HALF_EVEN),
                periodOutflows.setScale(2, RoundingMode.HALF_EVEN),
                closingBalance,
                items.size(),
                items
        );
    }

    @Transactional(readOnly = true)
    public byte[] generateStatementPdf(Long userId, Long accountId, LocalDate fromDate, LocalDate toDate)
    {
        StatementResponse statement = getStatement(userId, accountId, fromDate, toDate);

        try (ByteArrayOutputStream out = new ByteArrayOutputStream())
        {
            Document document = new Document(PageSize.A4, 36, 36, 40, 40);
            PdfWriter.getInstance(document, out);
            document.open();

            // Colors
            Color brandGreen = new Color(24, 76, 56);
            Color lightGreenBg = new Color(242, 247, 244);
            Color darkGrey = new Color(40, 40, 40);
            Color mutedGrey = new Color(110, 110, 110);
            Color debitRed = new Color(180, 40, 40);
            Color creditGreen = new Color(24, 128, 56);
            Color borderGrey = new Color(220, 225, 222);

            // Fonts
            Font titleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, brandGreen);
            Font subtitleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, darkGrey);
            Font boldFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, darkGrey);
            Font regularFont = FontFactory.getFont(FontFactory.HELVETICA, 9, darkGrey);
            Font mutedFont = FontFactory.getFont(FontFactory.HELVETICA, 8, mutedGrey);
            Font headerFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.WHITE);

            // Header Section
            PdfPTable headerTable = new PdfPTable(2);
            headerTable.setWidthPercentage(100);
            headerTable.setWidths(new float[]{60, 40});

            PdfPCell leftHeader = new PdfPCell();
            leftHeader.setBorder(Rectangle.NO_BORDER);
            leftHeader.addElement(new Paragraph("INTBank S.A.", titleFont));
            leftHeader.addElement(new Paragraph("Sucursala Digitala Centrala | Cod BIC: INTBROBUXXX", mutedFont));
            leftHeader.addElement(new Paragraph("Website: www.intbank.com | Suport: +40 21 9000", mutedFont));
            headerTable.addCell(leftHeader);

            PdfPCell rightHeader = new PdfPCell();
            rightHeader.setBorder(Rectangle.NO_BORDER);
            rightHeader.setHorizontalAlignment(Element.ALIGN_RIGHT);
            Paragraph docTitle = new Paragraph("EXTRAS DE CONT", FontFactory.getFont(FontFactory.HELVETICA_BOLD, 14, brandGreen));
            docTitle.setAlignment(Element.ALIGN_RIGHT);
            rightHeader.addElement(docTitle);
            Paragraph docSub = new Paragraph("BANK ACCOUNT STATEMENT", FontFactory.getFont(FontFactory.HELVETICA, 8, mutedGrey));
            docSub.setAlignment(Element.ALIGN_RIGHT);
            rightHeader.addElement(docSub);
            Paragraph docGen = new Paragraph("Emis la: " + statement.generatedAt(), FontFactory.getFont(FontFactory.HELVETICA, 8, mutedGrey));
            docGen.setAlignment(Element.ALIGN_RIGHT);
            rightHeader.addElement(docGen);
            headerTable.addCell(rightHeader);

            document.add(headerTable);
            document.add(new Paragraph(" ", FontFactory.getFont(FontFactory.HELVETICA, 6)));

            // Customer & Account Details Card
            PdfPTable detailsTable = new PdfPTable(2);
            detailsTable.setWidthPercentage(100);
            detailsTable.setWidths(new float[]{50, 50});

            PdfPCell c1 = new PdfPCell();
            c1.setBackgroundColor(lightGreenBg);
            c1.setBorderColor(borderGrey);
            c1.setPadding(10);
            c1.addElement(new Paragraph("TITULAR CONT / CLIENT:", mutedFont));
            c1.addElement(new Paragraph(statement.accountHolder(), subtitleFont));
            c1.addElement(new Paragraph("CNP / CIF: " + statement.cnp(), regularFont));
            detailsTable.addCell(c1);

            PdfPCell c2 = new PdfPCell();
            c2.setBackgroundColor(lightGreenBg);
            c2.setBorderColor(borderGrey);
            c2.setPadding(10);
            c2.addElement(new Paragraph("CONT IBAN (" + statement.currency() + "):", mutedFont));
            c2.addElement(new Paragraph(statement.iban(), subtitleFont));
            c2.addElement(new Paragraph("Perioada extras: " + statement.fromDate() + " - " + statement.toDate(), regularFont));
            detailsTable.addCell(c2);

            document.add(detailsTable);
            document.add(new Paragraph(" ", FontFactory.getFont(FontFactory.HELVETICA, 8)));

            // Financial Balance Summary Table
            PdfPTable summaryTable = new PdfPTable(4);
            summaryTable.setWidthPercentage(100);
            summaryTable.setWidths(new float[]{25, 25, 25, 25});

            addSummaryCell(summaryTable, "SOLD INITIAL", statement.openingBalance() + " " + statement.currency(), darkGrey, lightGreenBg, borderGrey, boldFont, mutedFont);
            addSummaryCell(summaryTable, "TOTAL INCASARI (+)", "+" + statement.totalInflows() + " " + statement.currency(), creditGreen, lightGreenBg, borderGrey, boldFont, mutedFont);
            addSummaryCell(summaryTable, "TOTAL PLATI (-)", "-" + statement.totalOutflows() + " " + statement.currency(), debitRed, lightGreenBg, borderGrey, boldFont, mutedFont);
            addSummaryCell(summaryTable, "SOLD FINAL", statement.closingBalance() + " " + statement.currency(), brandGreen, lightGreenBg, borderGrey, boldFont, mutedFont);

            document.add(summaryTable);
            document.add(new Paragraph(" ", FontFactory.getFont(FontFactory.HELVETICA, 10)));

            // Transaction Table
            Paragraph txHeader = new Paragraph("LISTA OPERATIUNILOR DIN PERIOADA (" + statement.transactionCount() + " tranzactii)", FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, brandGreen));
            document.add(txHeader);
            document.add(new Paragraph(" ", FontFactory.getFont(FontFactory.HELVETICA, 4)));

            PdfPTable txTable = new PdfPTable(5);
            txTable.setWidthPercentage(100);
            txTable.setWidths(new float[]{18, 12, 38, 17, 15});

            addHeaderCell(txTable, "Data & Ora", brandGreen, headerFont);
            addHeaderCell(txTable, "Tip", brandGreen, headerFont);
            addHeaderCell(txTable, "Detalii / Beneficiar", brandGreen, headerFont);
            addHeaderCell(txTable, "IBAN Contrapartida", brandGreen, headerFont);
            addHeaderCell(txTable, "Suma", brandGreen, headerFont);

            if (statement.transactions().isEmpty())
            {
                PdfPCell emptyCell = new PdfPCell(new Phrase("Nu exista operatiuni inregistrate in aceasta perioada.", regularFont));
                emptyCell.setColspan(5);
                emptyCell.setHorizontalAlignment(Element.ALIGN_CENTER);
                emptyCell.setPadding(15);
                emptyCell.setBorderColor(borderGrey);
                txTable.addCell(emptyCell);
            }
            else
            {
                boolean alt = false;
                for (StatementItem item : statement.transactions())
                {
                    Color rowBg = alt ? new Color(250, 252, 250) : Color.WHITE;
                    alt = !alt;

                    addRowCell(txTable, item.date(), Element.ALIGN_LEFT, rowBg, borderGrey, regularFont);
                    addRowCell(txTable, item.type(), Element.ALIGN_CENTER, rowBg, borderGrey, boldFont);
                    addRowCell(txTable, item.partyName() + "\n" + item.description(), Element.ALIGN_LEFT, rowBg, borderGrey, regularFont);
                    addRowCell(txTable, item.partyIban(), Element.ALIGN_LEFT, rowBg, borderGrey, mutedFont);

                    Color amountColor = "DEBIT".equals(item.type()) ? debitRed : creditGreen;
                    String sign = "DEBIT".equals(item.type()) ? "-" : "+";
                    Font amtFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, amountColor);
                    addRowCell(txTable, sign + item.amount() + " " + item.currency(), Element.ALIGN_RIGHT, rowBg, borderGrey, amtFont);
                }
            }

            document.add(txTable);

            // Stamp & Legal Footer
            document.add(new Paragraph(" ", FontFactory.getFont(FontFactory.HELVETICA, 14)));

            PdfPTable footerTable = new PdfPTable(2);
            footerTable.setWidthPercentage(100);
            footerTable.setWidths(new float[]{70, 30});

            PdfPCell legalCell = new PdfPCell();
            legalCell.setBorder(Rectangle.NO_BORDER);
            legalCell.addElement(new Paragraph("NOTA DE CONFORMITATE BANCARA:", FontFactory.getFont(FontFactory.HELVETICA_BOLD, 8, mutedGrey)));
            legalCell.addElement(new Paragraph(
                    "Prezentul extras de cont a fost generat automat prin serviciul de Internet Banking INTBank " +
                    "si constituie document justificativ conform legislatiei in vigoare (Legea 209/2019 si Regulamentul BNR). " +
                    "Valabil fara semnatura olografa sau stampila.", mutedFont));
            footerTable.addCell(legalCell);

            PdfPCell stampCell = new PdfPCell();
            stampCell.setBorder(Rectangle.NO_BORDER);
            stampCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
            Paragraph stamp = new Paragraph("[CONFIRMAT] DOCUMENT VERIFICAT ELECTRONIC\nINTBANK SISTEM CENTRAL", FontFactory.getFont(FontFactory.HELVETICA_BOLD, 7, brandGreen));
            stamp.setAlignment(Element.ALIGN_RIGHT);
            stampCell.addElement(stamp);
            footerTable.addCell(stampCell);

            document.add(footerTable);
            document.close();

            auditLogService.log(userId, "STATEMENT_PDF_DOWNLOADED",
                    "Statement PDF downloaded for " + statement.iban() + " (" + fromDate + " -> " + toDate + ")", "127.0.0.1");

            return out.toByteArray();
        }
        catch (Exception e)
        {
            log.error("Failed to generate statement PDF for account {}", accountId, e);
            throw new RuntimeException("Eroare la generarea extrasului PDF", e);
        }
    }

    private void addSummaryCell(PdfPTable table, String label, String value, Color valColor, Color bgColor, Color borderColor, Font valFont, Font labelFont)
    {
        PdfPCell cell = new PdfPCell();
        cell.setBackgroundColor(bgColor);
        cell.setBorderColor(borderColor);
        cell.setPadding(8);
        cell.addElement(new Paragraph(label, labelFont));
        Font customFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, valColor);
        cell.addElement(new Paragraph(value, customFont));
        table.addCell(cell);
    }

    private void addHeaderCell(PdfPTable table, String text, Color bgColor, Font font)
    {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setBackgroundColor(bgColor);
        cell.setPadding(6);
        cell.setHorizontalAlignment(Element.ALIGN_CENTER);
        table.addCell(cell);
    }

    private void addRowCell(PdfPTable table, String text, int align, Color bgColor, Color borderColor, Font font)
    {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setBackgroundColor(bgColor);
        cell.setBorderColor(borderColor);
        cell.setHorizontalAlignment(align);
        cell.setPadding(6);
        table.addCell(cell);
    }

    private AccountJpaEntity validateAndGetAccount(Long userId, Long accountId)
    {
        var accountOpt = accountRepo.findById(accountId);
        if (accountOpt.isEmpty())
        {
            throw new IllegalArgumentException("Contul nu a fost găsit");
        }
        AccountJpaEntity account = accountOpt.get();
        if (account.getUserId() == null || !account.getUserId().equals(userId))
        {
            throw new IllegalArgumentException("Acces neautorizat la cont");
        }
        return account;
    }

    private void validateDateRange(LocalDate fromDate, LocalDate toDate)
    {
        if (fromDate == null || toDate == null)
        {
            throw new IllegalArgumentException("Datele de început și sfârșit sunt obligatorii");
        }
        if (fromDate.isAfter(toDate))
        {
            throw new IllegalArgumentException("Data de început nu poate fi ulterioară datei de sfârșit");
        }
        if (toDate.isAfter(LocalDate.now()))
        {
            throw new IllegalArgumentException("Data de sfârșit nu poate fi în viitor");
        }
        long days = ChronoUnit.DAYS.between(fromDate, toDate);
        if (days > 366)
        {
            throw new IllegalArgumentException("Perioada maximă pentru generarea extrasului este de 1 an (365 de zile)");
        }
    }
}
