import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/services/utility_invoice_parser_service.dart';

const String enelIban = 'RO32ENEL1B31007593840000';
const String eonIban = 'RO04EONB1B31007593840001';
const String digiIban = 'RO59DIGI1B31007593840002';
const String orangeIban = 'RO59ORAN1B31007593840003';
const String vodafoneIban = 'RO11VODA1B31007593840004';
const String sampleIban = 'RO49AAAA1B31007593840000';

String keyValue({
  String provider = 'ENEL',
  String client = '123456',
  String invoice = 'INV-2026-001',
  String amount = '245.50',
  String due = '15.03.2026',
  String iban = enelIban,
  String separator = ';',
}) {
  return 'PROVIDER=$provider$separator'
      'CLIENT=$client$separator'
      'INVOICE=$invoice$separator'
      'AMOUNT=$amount$separator'
      'DUEDATE=$due$separator'
      'IBAN=$iban';
}

String positional({
  String provider = 'ENEL',
  String customer = '123456',
  String invoice = 'INV-2026-001',
  String amount = '245.50',
  String due = '15.03.2026',
  String iban = enelIban,
}) {
  return '$provider|$customer|$invoice|$amount|$due|$iban';
}

String obfuscateAmount(int bani) {
  final String digits = bani.toString().padLeft(8, '0');
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int digit = int.parse(digits[i]);
    buffer.write(((digit + i) % 10).toString());
  }
  return buffer.toString();
}

String factura({
  String providerCode = '01',
  String customer = '0000001234',
  String invoice = '0000000001',
  int bani = 24550,
  String due = '150326',
  String iban = enelIban,
}) {
  return '$providerCode$customer$invoice${obfuscateAmount(bani)}$due$iban';
}

List<int> code128B(String text) {
  final List<int> symbols = <int>[104];
  for (final int unit in text.codeUnits) {
    symbols.add(unit - 32);
  }
  final int checksum = UtilityInvoiceParserService().computeCode128Checksum(
    symbols,
  );
  symbols.add(checksum);
  symbols.add(106);
  return symbols;
}

List<int> code128C(String digits) {
  final List<int> symbols = <int>[105];
  for (int i = 0; i < digits.length; i += 2) {
    symbols.add(int.parse(digits.substring(i, i + 2)));
  }
  final int checksum = UtilityInvoiceParserService().computeCode128Checksum(
    symbols,
  );
  symbols.add(checksum);
  symbols.add(106);
  return symbols;
}

void main() {
  final service = UtilityInvoiceParserService();

  group('isValidRomanianIban', () {
    test('accepts valid Romanian provider IBANs', () {
      expect(service.isValidRomanianIban(enelIban), isTrue);
      expect(service.isValidRomanianIban(eonIban), isTrue);
      expect(service.isValidRomanianIban(digiIban), isTrue);
      expect(service.isValidRomanianIban(orangeIban), isTrue);
      expect(service.isValidRomanianIban(vodafoneIban), isTrue);
      expect(service.isValidRomanianIban(sampleIban), isTrue);
    });

    test('accepts lower case with spaces', () {
      expect(
        service.isValidRomanianIban('ro32 enel 1b31 0075 9384 0000'),
        isTrue,
      );
    });

    test('rejects a wrong mod-97 checksum', () {
      expect(service.isValidRomanianIban('RO32ENEL1B31007593840001'), isFalse);
      expect(service.isValidRomanianIban('RO49AAAA1B31007593840001'), isFalse);
    });

    test('rejects wrong length', () {
      expect(service.isValidRomanianIban('RO32ENEL1B310075938400'), isFalse);
      expect(
        service.isValidRomanianIban('RO32ENEL1B310075938400000'),
        isFalse,
      );
    });

    test('rejects a non Romanian IBAN', () {
      expect(service.isValidRomanianIban('DE89370400440532013000'), isFalse);
    });

    test('rejects illegal characters', () {
      expect(service.isValidRomanianIban('RO32ENEL1B310075938400@0'), isFalse);
    });
  });

  group('detectProvider', () {
    test('detects every supported provider by keyword', () {
      expect(service.detectProvider('ENEL ENERGIE'), UtilityProviderType.enel);
      expect(service.detectProvider('E.ON GAZ'), UtilityProviderType.eon);
      expect(service.detectProvider('EON'), UtilityProviderType.eon);
      expect(service.detectProvider('DIGI ROMANIA'), UtilityProviderType.digi);
      expect(service.detectProvider('RCS&RDS'), UtilityProviderType.digi);
      expect(service.detectProvider('ORANGE'), UtilityProviderType.orange);
      expect(service.detectProvider('VODAFONE'), UtilityProviderType.vodafone);
    });

    test('returns unknown for unrecognized text', () {
      expect(service.detectProvider('SOMEPROVIDER'), UtilityProviderType.unknown);
      expect(service.detectProvider(''), UtilityProviderType.unknown);
    });

    test('maps provider types to canonical names', () {
      expect(service.providerNameFor(UtilityProviderType.enel), 'Enel');
      expect(service.providerNameFor(UtilityProviderType.eon), 'E.ON');
      expect(service.providerNameFor(UtilityProviderType.digi), 'Digi');
      expect(service.providerNameFor(UtilityProviderType.orange), 'Orange');
      expect(service.providerNameFor(UtilityProviderType.vodafone), 'Vodafone');
      expect(service.providerNameFor(UtilityProviderType.unknown), 'Unknown');
    });
  });

  group('parseQr key value', () {
    test('parses every provider from a semicolon record', () {
      final Map<String, UtilityProviderType> providers =
          <String, UtilityProviderType>{
        'ENEL': UtilityProviderType.enel,
        'E.ON': UtilityProviderType.eon,
        'DIGI': UtilityProviderType.digi,
        'ORANGE': UtilityProviderType.orange,
        'VODAFONE': UtilityProviderType.vodafone,
      };
      providers.forEach((String name, UtilityProviderType type) {
        final ParsedUtilityInvoice invoice = service.parseQr(
          keyValue(provider: name),
        );
        expect(invoice.providerType, type, reason: name);
      });
    });

    test('parses all fields from a key value record', () {
      final ParsedUtilityInvoice invoice = service.parseQr(keyValue());
      expect(invoice.providerName, 'Enel');
      expect(invoice.providerType, UtilityProviderType.enel);
      expect(invoice.customerCode, '123456');
      expect(invoice.invoiceNumber, 'INV-2026-001');
      expect(invoice.amount, 245.5);
      expect(invoice.dueDate, DateTime.utc(2026, 3, 15));
      expect(invoice.paymentIban, enelIban);
    });

    test('accepts comma delimiters and lower case keys', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        'provider=orange,client=99,invoice=F-1,amount=10.00,'
        'duedate=2026-01-01,iban=$orangeIban',
      );
      expect(invoice.providerType, UtilityProviderType.orange);
      expect(invoice.amount, 10.0);
    });

    test('accepts Romanian aliases', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        'FURNIZOR=vodafone;CODCLIENT=7;NRFACTURA=F-7;TOTAL=80,25;'
        'SCADENTA=010126;CONT=$vodafoneIban',
      );
      expect(invoice.providerType, UtilityProviderType.vodafone);
      expect(invoice.customerCode, '7');
      expect(invoice.invoiceNumber, 'F-7');
      expect(invoice.amount, 80.25);
      expect(invoice.dueDate, DateTime.utc(2026, 1, 1));
    });

    test('detects provider from the IBAN when the provider is missing', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(provider: '', iban: digiIban),
      );
      expect(invoice.providerType, UtilityProviderType.digi);
      expect(invoice.providerName, 'Digi');
    });

    test('keeps an unknown provider when nothing identifies it', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(provider: 'SOMEPROVIDER', iban: sampleIban),
      );
      expect(invoice.providerType, UtilityProviderType.unknown);
      expect(invoice.providerName, 'SOMEPROVIDER');
    });

    test('applies the provider hint for unknown providers', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(provider: 'SOMEPROVIDER', iban: sampleIban),
        providerHint: UtilityProviderType.vodafone,
      );
      expect(invoice.providerType, UtilityProviderType.vodafone);
      expect(invoice.providerName, 'Vodafone');
    });

    test('rejects a malformed segment', () {
      expect(
        () => service.parseQr('PROVIDER=ENEL;CLIENT;INVOICE=1'),
        throwsFormatException,
      );
    });

    test('rejects missing customer code', () {
      expect(
        () => service.parseQr(keyValue(client: '')),
        throwsFormatException,
      );
    });

    test('rejects missing invoice number', () {
      expect(
        () => service.parseQr(keyValue(invoice: '')),
        throwsFormatException,
      );
    });

    test('rejects an invalid IBAN', () {
      expect(
        () => service.parseQr(keyValue(iban: 'RO32ENEL1B31007593840001')),
        throwsFormatException,
      );
    });

    test('rejects a zero amount', () {
      expect(
        () => service.parseQr(keyValue(amount: '0.00')),
        throwsFormatException,
      );
    });

    test('rejects an amount above the maximum', () {
      expect(
        () => service.parseQr(keyValue(amount: '100000.01')),
        throwsFormatException,
      );
    });

    test('rejects a non numeric amount', () {
      expect(
        () => service.parseQr(keyValue(amount: 'abc')),
        throwsFormatException,
      );
    });
  });

  group('parseQr positional', () {
    test('parses every provider from a pipe record', () {
      final List<String> records = <String>[
        positional(provider: 'ENEL', iban: enelIban),
        positional(provider: 'E.ON', iban: eonIban),
        positional(provider: 'DIGI', iban: digiIban),
        positional(provider: 'ORANGE', iban: orangeIban),
        positional(provider: 'VODAFONE', iban: vodafoneIban),
      ];
      final List<UtilityProviderType> expected = <UtilityProviderType>[
        UtilityProviderType.enel,
        UtilityProviderType.eon,
        UtilityProviderType.digi,
        UtilityProviderType.orange,
        UtilityProviderType.vodafone,
      ];
      for (int i = 0; i < records.length; i++) {
        expect(service.parseQr(records[i]).providerType, expected[i]);
      }
    });

    test('rejects a wrong field count', () {
      expect(
        () => service.parseQr('ENEL|123|INV|10.00|2026-01-01'),
        throwsFormatException,
      );
      expect(
        () => service.parseQr('ENEL|123|INV|10.00|2026-01-01|$enelIban|EXTRA'),
        throwsFormatException,
      );
    });
  });

  group('factura barcode convention', () {
    test('parses the obfuscated amount and date', () {
      final ParsedUtilityInvoice invoice = service.parse(factura());
      expect(invoice.providerType, UtilityProviderType.enel);
      expect(invoice.providerName, 'Enel');
      expect(invoice.customerCode, '1234');
      expect(invoice.invoiceNumber, '1');
      expect(invoice.amount, 245.5);
      expect(invoice.dueDate, DateTime.utc(2026, 3, 15));
      expect(invoice.paymentIban, enelIban);
    });

    test('decodes the amount obfuscation deterministically', () {
      final ParsedUtilityInvoice invoice = service.parse(
        factura(bani: 100),
      );
      expect(invoice.amount, 1.0);
    });

    test('parses every provider code', () {
      expect(
        service.parse(factura(providerCode: '02', iban: eonIban)).providerType,
        UtilityProviderType.eon,
      );
      expect(
        service.parse(factura(providerCode: '03', iban: digiIban)).providerType,
        UtilityProviderType.digi,
      );
      expect(
        service
            .parse(factura(providerCode: '04', iban: orangeIban))
            .providerType,
        UtilityProviderType.orange,
      );
      expect(
        service
            .parse(factura(providerCode: '05', iban: vodafoneIban))
            .providerType,
        UtilityProviderType.vodafone,
      );
    });

    test('falls back to the IBAN for an unknown provider code', () {
      expect(
        service.parse(factura(providerCode: '99', iban: enelIban)).providerType,
        UtilityProviderType.enel,
      );
      expect(
        service
            .parse(factura(providerCode: '99', iban: sampleIban))
            .providerType,
        UtilityProviderType.unknown,
      );
    });

    test('rejects a malformed factura payload', () {
      expect(() => service.parse('12345RO32ENEL'), throwsFormatException);
    });

    test('rejects an amount above the maximum', () {
      expect(
        () => service.parse(factura(bani: 10000001)),
        throwsFormatException,
      );
    });
  });

  group('Code 39', () {
    test('decodes a delimited character string', () {
      expect(service.decodeCode39('*ENEL*'), 'ENEL');
      expect(service.decodeCode39('*ABC-123*'), 'ABC-123');
      expect(service.decodeCode39('*abc*'), 'ABC');
    });

    test('decodes width patterns', () {
      const String patterns =
          'nwnnwnwnnwnnnnwnnwnnwnnwnnwnwnnwnwnn';
      expect(service.decodeCode39Patterns(patterns), '*AB*');
    });

    test('rejects a missing delimiter', () {
      expect(() => service.decodeCode39('ENEL'), throwsFormatException);
    });

    test('rejects an empty payload', () {
      expect(() => service.decodeCode39('**'), throwsFormatException);
    });

    test('rejects an invalid character', () {
      expect(() => service.decodeCode39('*A@B*'), throwsFormatException);
    });

    test('rejects malformed patterns', () {
      expect(() => service.decodeCode39Patterns('nwn'), throwsFormatException);
      expect(
        () => service.decodeCode39Patterns('wwwwwwwww'),
        throwsFormatException,
      );
    });

    test('parseBarcode decodes Code 39 then parses the record', () {
      final String wrapped = '*${factura()}*';
      final ParsedUtilityInvoice invoice = service.parseBarcode(wrapped);
      expect(invoice.providerType, UtilityProviderType.enel);
      expect(invoice.amount, 245.5);
    });
  });

  group('Code 128', () {
    test('decodes Code Set B text', () {
      final List<int> symbols = code128B('HELLO');
      expect(service.decodeCode128Symbols(symbols), 'HELLO');
    });

    test('decodes Code Set C digit pairs', () {
      final List<int> symbols = code128C('12345678');
      expect(service.decodeCode128Symbols(symbols), '12345678');
    });

    test('switches from Code Set B to Code Set C', () {
      final List<int> symbols = <int>[104, 33, 34, 99, 12, 34];
      final int checksum = service.computeCode128Checksum(symbols);
      symbols
        ..add(checksum)
        ..add(106);
      expect(service.decodeCode128Symbols(symbols), 'AB1234');
    });

    test('decodes the string symbol representation', () {
      final List<int> symbols = code128B('ENEL');
      final String encoded =
          symbols.map((int value) => value.toString()).join(' ');
      expect(service.decodeCode128(encoded), 'ENEL');
      expect(
        service.decodeCode128(symbols.join(',')),
        'ENEL',
      );
    });

    test('rejects a checksum mismatch', () {
      final List<int> symbols = code128B('HELLO');
      symbols[symbols.length - 2] = (symbols[symbols.length - 2] + 1) % 103;
      expect(
        () => service.decodeCode128Symbols(symbols),
        throwsFormatException,
      );
    });

    test('rejects a missing stop symbol', () {
      final List<int> symbols = code128B('HELLO');
      symbols[symbols.length - 1] = 5;
      expect(
        () => service.decodeCode128Symbols(symbols),
        throwsFormatException,
      );
    });

    test('rejects an out of range symbol', () {
      expect(
        () => service.decodeCode128Symbols(<int>[104, 200, 0, 106]),
        throwsFormatException,
      );
    });

    test('rejects Code Set A', () {
      expect(
        () => service.decodeCode128Symbols(<int>[103, 0, 0, 106]),
        throwsFormatException,
      );
    });

    test('rejects a too short payload', () {
      expect(
        () => service.decodeCode128Symbols(<int>[104, 106]),
        throwsFormatException,
      );
    });

    test('parseBarcode decodes Code 128 then parses the record', () {
      final String encoded =
          code128B(positional()).map((int value) => value.toString()).join(' ');
      final ParsedUtilityInvoice invoice = service.parseBarcode(encoded);
      expect(invoice.providerType, UtilityProviderType.enel);
      expect(invoice.amount, 245.5);
    });
  });

  group('due date parsing and validation', () {
    test('parses dd.MM.yyyy', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(due: '15.03.2026'),
      );
      expect(invoice.dueDate, DateTime.utc(2026, 3, 15));
    });

    test('parses yyyy-MM-dd', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(due: '2026-03-15'),
      );
      expect(invoice.dueDate, DateTime.utc(2026, 3, 15));
    });

    test('parses ddMMyy', () {
      final ParsedUtilityInvoice invoice = service.parseQr(
        keyValue(due: '150326'),
      );
      expect(invoice.dueDate, DateTime.utc(2026, 3, 15));
    });

    test('rejects an impossible calendar date', () {
      expect(
        () => service.parseQr(keyValue(due: '31.02.2026')),
        throwsFormatException,
      );
    });

    test('rejects an unsupported format', () {
      expect(
        () => service.parseQr(keyValue(due: '2026/03/15')),
        throwsFormatException,
      );
    });

    test('rejects a date before the minimum', () {
      expect(
        () => service.parseQr(keyValue(due: '01.01.1999')),
        throwsFormatException,
      );
    });

    test('rejects a date beyond the deterministic future window', () {
      final UtilityInvoiceParserService fixed = UtilityInvoiceParserService(
        now: () => DateTime.utc(2026, 1, 1),
      );
      expect(
        () => fixed.parseQr(keyValue(due: '2099-01-01')),
        throwsFormatException,
      );
    });

    test('accepts a date inside the future window', () {
      final UtilityInvoiceParserService fixed = UtilityInvoiceParserService(
        now: () => DateTime.utc(2026, 1, 1),
      );
      expect(
        fixed.parseQr(keyValue(due: '2030-01-01')).dueDate,
        DateTime.utc(2030, 1, 1),
      );
    });
  });

  group('amount rules', () {
    test('accepts a comma decimal separator', () {
      expect(service.parseQr(keyValue(amount: '245,50')).amount, 245.5);
    });

    test('accepts an integer amount', () {
      expect(service.parseQr(keyValue(amount: '100')).amount, 100.0);
    });

    test('accepts the maximum amount', () {
      expect(service.parseQr(keyValue(amount: '100000')).amount, 100000.0);
    });

    test('rejects a negative amount', () {
      expect(
        () => service.parseQr(keyValue(amount: '-5.00')),
        throwsFormatException,
      );
    });

    test('rejects more than two decimals', () {
      expect(
        () => service.parseQr(keyValue(amount: '12.505')),
        throwsFormatException,
      );
    });
  });

  group('parse auto detection', () {
    test('detects the key value convention', () {
      expect(service.parse(keyValue()).providerType, UtilityProviderType.enel);
    });

    test('detects the pipe convention', () {
      expect(service.parse(positional()).amount, 245.5);
    });

    test('detects the factura convention', () {
      expect(service.parse(factura()).amount, 245.5);
    });

    test('detects Code 39', () {
      expect(
        service.parse('*${factura()}*').providerType,
        UtilityProviderType.enel,
      );
    });

    test('detects Code 128', () {
      final String encoded =
          code128B(positional()).map((int value) => value.toString()).join(' ');
      expect(service.parse(encoded).providerType, UtilityProviderType.enel);
    });

    test('rejects empty and unrecognized payloads', () {
      expect(() => service.parse(''), throwsFormatException);
      expect(() => service.parse('   '), throwsFormatException);
      expect(() => service.parse('HELLO WORLD'), throwsFormatException);
    });
  });

  group('ParsedUtilityInvoice', () {
    final ParsedUtilityInvoice invoice = ParsedUtilityInvoice(
      providerName: 'Enel',
      providerType: UtilityProviderType.enel,
      customerCode: '123456',
      invoiceNumber: 'INV-1',
      amount: 245.5,
      dueDate: DateTime.utc(2026, 3, 15),
      paymentIban: enelIban,
    );

    test('copyWith replaces only the requested fields', () {
      final ParsedUtilityInvoice updated = invoice.copyWith(amount: 10.0);
      expect(updated.amount, 10.0);
      expect(updated.providerName, invoice.providerName);
      expect(updated.paymentIban, invoice.paymentIban);
    });

    test('implements value equality and hashCode', () {
      final ParsedUtilityInvoice same = ParsedUtilityInvoice(
        providerName: 'Enel',
        providerType: UtilityProviderType.enel,
        customerCode: '123456',
        invoiceNumber: 'INV-1',
        amount: 245.5,
        dueDate: DateTime.utc(2026, 3, 15),
        paymentIban: enelIban,
      );
      expect(same, invoice);
      expect(same.hashCode, invoice.hashCode);
      expect(invoice.copyWith(amount: 1.0), isNot(invoice));
    });

    test('exposes a JSON map', () {
      final Map<String, dynamic> json = invoice.toJson();
      expect(json['providerType'], 'enel');
      expect(json['amount'], 245.5);
      expect(json['paymentIban'], enelIban);
    });

    test('toString exposes the class name', () {
      expect(invoice.toString(), contains('ParsedUtilityInvoice'));
    });
  });
}
