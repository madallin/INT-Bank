import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/services/qr_payment_service.dart';

QrPaymentPayload buildPayload({
  String beneficiaryName = 'Acme SRL',
  String iban = 'RO49AAAA1B31007593840000',
  String? bic = 'RNCBROBU',
  double amount = 12.5,
  String currency = 'RON',
  String? remittanceReference = 'INV-123',
  String? purposeCode = 'GDDS',
}) {
  return QrPaymentPayload(
    beneficiaryName: beneficiaryName,
    iban: iban,
    bic: bic,
    amount: amount,
    currency: currency,
    remittanceReference: remittanceReference,
    purposeCode: purposeCode,
  );
}

String epcWithAmount(String amountLine) {
  return <String>[
    'BCD',
    '002',
    '1',
    'SCT',
    '',
    'Acme SRL',
    'RO49AAAA1B31007593840000',
    amountLine,
    '',
    '',
  ].join('\n');
}

void main() {
  final service = QrPaymentService();

  group('isValidIban', () {
    test('accepts the German sample IBAN', () {
      expect(service.isValidIban('DE89370400440532013000'), isTrue);
    });

    test('accepts the United Kingdom sample IBAN', () {
      expect(service.isValidIban('GB29NWBK60161331926819'), isTrue);
    });

    test('accepts the Romanian sample IBAN', () {
      expect(service.isValidIban('RO49AAAA1B31007593840000'), isTrue);
    });

    test('accepts lower case IBAN with spaces', () {
      expect(service.isValidIban('de89 3704 0044 0532 0130 00'), isTrue);
    });

    test('rejects an IBAN with a wrong checksum', () {
      expect(service.isValidIban('DE89370400440532013001'), isFalse);
      expect(service.isValidIban('GB29NWBK60161331926818'), isFalse);
    });

    test('rejects an IBAN with illegal characters', () {
      expect(service.isValidIban('RO49AAAA1B3100759384@000'), isFalse);
      expect(service.isValidIban('RO49-AAA1-B31007593840000'), isFalse);
    });

    test('rejects an IBAN that is too short', () {
      expect(service.isValidIban('DE11'), isFalse);
      expect(service.isValidIban(''), isFalse);
    });

    test('rejects an IBAN that is too long', () {
      final String tooLong = List<String>.filled(35, 'A').join();
      expect(service.isValidIban(tooLong), isFalse);
    });
  });

  group('detectStandard', () {
    test('detects EPC SEPA from a generated payload', () {
      final String payload = service.generateEpcPayload(buildPayload());
      expect(service.detectStandard(payload), QrStandardType.epcSepa);
    });

    test('detects RoPay instant from a generated payload', () {
      final String payload = service.generateRoPayPayload(buildPayload());
      expect(service.detectStandard(payload), QrStandardType.roPayInstant);
    });

    test('detects EPC after leading whitespace', () {
      expect(service.detectStandard('  BCD\n002'), QrStandardType.epcSepa);
    });

    test('detects RoPay with trailing whitespace', () {
      expect(service.detectStandard('ROPAY1|a'), QrStandardType.roPayInstant);
    });

    test('returns unknown for unrelated content', () {
      expect(service.detectStandard('HELLO WORLD'), QrStandardType.unknown);
      expect(service.detectStandard(''), QrStandardType.unknown);
    });
  });

  group('generateEpcPayload', () {
    test('produces the fixed ten line EPC layout', () {
      final String result = service.generateEpcPayload(buildPayload());
      expect(
        result,
        'BCD\n002\n1\nSCT\nRNCBROBU\nAcme SRL\n'
        'RO49AAAA1B31007593840000\nRON12.50\nGDDS\nINV-123',
      );
    });

    test('preserves an empty BIC line', () {
      final String result = service.generateEpcPayload(buildPayload(bic: null));
      expect(result.split('\n')[4], '');
    });

    test('formats the amount as currency followed by two decimals', () {
      final String result = service.generateEpcPayload(
        buildPayload(amount: 7.5, currency: 'EUR'),
      );
      expect(result.split('\n')[7], 'EUR7.50');
    });

    test('accepts a 70 character beneficiary name', () {
      final String name = List<String>.filled(70, 'A').join();
      final String result = service.generateEpcPayload(
        buildPayload(beneficiaryName: name),
      );
      expect(result.contains(name), isTrue);
    });

    test('rejects a 71 character beneficiary name', () {
      final String name = List<String>.filled(71, 'A').join();
      expect(
        () => service.generateEpcPayload(buildPayload(beneficiaryName: name)),
        throwsArgumentError,
      );
    });

    test('accepts a 140 character remittance reference', () {
      final String reference = List<String>.filled(140, 'R').join();
      final String result = service.generateEpcPayload(
        buildPayload(remittanceReference: reference),
      );
      expect(result.endsWith(reference), isTrue);
    });

    test('rejects a 141 character remittance reference', () {
      final String reference = List<String>.filled(141, 'R').join();
      expect(
        () => service.generateEpcPayload(
          buildPayload(remittanceReference: reference),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an invalid IBAN', () {
      expect(
        () => service.generateEpcPayload(
          buildPayload(iban: 'DE89370400440532013001'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non positive amount', () {
      expect(
        () => service.generateEpcPayload(buildPayload(amount: 0)),
        throwsArgumentError,
      );
    });
  });

  group('parsePayload EPC round trip', () {
    test('parses every field back from a generated payload', () {
      final QrPaymentPayload original = buildPayload();
      final QrPaymentPayload parsed =
          service.parsePayload(service.generateEpcPayload(original));

      expect(parsed.beneficiaryName, original.beneficiaryName);
      expect(parsed.iban, original.iban);
      expect(parsed.bic, original.bic);
      expect(parsed.amount, original.amount);
      expect(parsed.currency, original.currency);
      expect(parsed.remittanceReference, original.remittanceReference);
      expect(parsed.purposeCode, original.purposeCode);
      expect(parsed, original);
    });

    test('parses a payload with empty optional fields as null', () {
      final QrPaymentPayload original = buildPayload(
        bic: null,
        remittanceReference: null,
        purposeCode: null,
      );
      final QrPaymentPayload parsed =
          service.parsePayload(service.generateEpcPayload(original));

      expect(parsed.bic, isNull);
      expect(parsed.remittanceReference, isNull);
      expect(parsed.purposeCode, isNull);
    });
  });

  group('EPC amount rules', () {
    test('accepts a positive amount with two decimals', () {
      final QrPaymentPayload parsed = service.parsePayload(epcWithAmount('RON12.50'));
      expect(parsed.amount, 12.5);
      expect(parsed.currency, 'RON');
    });

    test('accepts an integer amount', () {
      final QrPaymentPayload parsed = service.parsePayload(epcWithAmount('EUR12'));
      expect(parsed.amount, 12.0);
      expect(parsed.currency, 'EUR');
    });

    test('rejects a zero amount', () {
      expect(
        () => service.parsePayload(epcWithAmount('EUR0.00')),
        throwsFormatException,
      );
    });

    test('rejects a negative amount', () {
      expect(
        () => service.parsePayload(epcWithAmount('EUR-5.00')),
        throwsFormatException,
      );
    });

    test('rejects an amount with three decimals', () {
      expect(
        () => service.parsePayload(epcWithAmount('EUR12.505')),
        throwsFormatException,
      );
    });

    test('rejects a non numeric amount', () {
      expect(
        () => service.parsePayload(epcWithAmount('EURabc')),
        throwsFormatException,
      );
      expect(
        () => service.parsePayload(epcWithAmount('EUR12,50')),
        throwsFormatException,
      );
    });
  });

  group('generateRoPayPayload', () {
    test('produces the documented pipe delimited record with a CRC16', () {
      final String result = service.generateRoPayPayload(buildPayload());
      const String prefix =
          'ROPAY1|RO49AAAA1B31007593840000|Acme SRL|12.50|RON|INV-123';
      expect(result, '$prefix|${service.computeCrc16(prefix)}');
    });

    test('encodes an empty reference as an empty field', () {
      final String result = service.generateRoPayPayload(
        buildPayload(remittanceReference: null),
      );
      final List<String> parts = result.split('|');
      expect(parts.length, 7);
      expect(parts[5], '');
    });

    test('is deterministic for identical input', () {
      final QrPaymentPayload payload = buildPayload();
      expect(
        service.generateRoPayPayload(payload),
        service.generateRoPayPayload(payload),
      );
    });

    test('rejects an invalid IBAN', () {
      expect(
        () => service.generateRoPayPayload(
          buildPayload(iban: 'RO49AAAA1B31007593840001'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a pipe character in the name', () {
      expect(
        () => service.generateRoPayPayload(
          buildPayload(beneficiaryName: 'Acme|SRL'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('parsePayload RoPay round trip', () {
    test('parses every field back from a generated payload', () {
      final QrPaymentPayload original = buildPayload(
        currency: 'RON',
        amount: 99.99,
      );
      final QrPaymentPayload parsed =
          service.parsePayload(service.generateRoPayPayload(original));

      expect(parsed.beneficiaryName, original.beneficiaryName);
      expect(parsed.iban, original.iban);
      expect(parsed.amount, original.amount);
      expect(parsed.currency, original.currency);
      expect(parsed.remittanceReference, original.remittanceReference);
      expect(parsed.bic, isNull);
      expect(parsed.purposeCode, isNull);
    });

    test('rejects a corrupted CRC16 checksum', () {
      final String payload = service.generateRoPayPayload(buildPayload());
      final String lastCharacter = payload.substring(payload.length - 1);
      final String corrupted = payload.substring(0, payload.length - 1) +
          (lastCharacter == '0' ? '1' : '0');

      expect(() => service.parsePayload(corrupted), throwsFormatException);
      expect(service.validatePayload(corrupted), isFalse);
      expect(service.validatePayload(payload), isTrue);
    });

    test('rejects a payload whose field was tampered with', () {
      final String payload = service.generateRoPayPayload(buildPayload());
      final String tampered = payload.replaceFirst('Acme SRL', 'Acme SA');
      expect(() => service.parsePayload(tampered), throwsFormatException);
      expect(service.validatePayload(tampered), isFalse);
    });
  });

  group('malformed and resilient input', () {
    test('parsePayload throws FormatException for unknown standards', () {
      expect(() => service.parsePayload(''), throwsFormatException);
      expect(() => service.parsePayload('   '), throwsFormatException);
      expect(() => service.parsePayload('HELLO WORLD'), throwsFormatException);
    });

    test('parsePayload throws for a truncated EPC payload', () {
      expect(
        () => service.parsePayload('BCD\n002\n1\nSCT'),
        throwsFormatException,
      );
      expect(() => service.parsePayload('BCD'), throwsFormatException);
    });

    test('parsePayload throws for an EPC header mismatch', () {
      expect(
        () => service.parsePayload(
          'BCD\n003\n1\nSCT\n\nName\nRO49AAAA1B31007593840000\nEUR1.00\n\n',
        ),
        throwsFormatException,
      );
    });

    test('parsePayload throws for unexpected EPC delimiters', () {
      expect(
        () => service.parsePayload('BCD\t002\t1\tSCT'),
        throwsFormatException,
      );
    });

    test('parsePayload throws for a RoPay field count mismatch', () {
      expect(
        () => service.parsePayload(
          'ROPAY1|RO49AAAA1B31007593840000|Acme|12.50|RON|INV-123',
        ),
        throwsFormatException,
      );
      expect(
        () => service.parsePayload(
          'ROPAY1|RO49AAAA1B31007593840000|Acme|12.50|RON|INV-123|ABCD|EXTRA',
        ),
        throwsFormatException,
      );
    });

    test('parsePayload throws for an invalid RoPay service tag', () {
      expect(
        () => service.parsePayload(
          'ROPAY2|RO49AAAA1B31007593840000|Acme|12.50|RON||0000',
        ),
        throwsFormatException,
      );
    });

    test('validatePayload returns false instead of throwing', () {
      final List<String> invalid = <String>[
        '',
        'HELLO',
        'BCD',
        'BCD\n002\n1\nSCT',
        'ROPAY1|only|two|fields',
        epcWithAmount('EUR0.00'),
        epcWithAmount('EUR12.505'),
      ];
      for (final String value in invalid) {
        expect(service.validatePayload(value), isFalse, reason: value);
      }
    });

    test('validatePayload returns true for valid payloads', () {
      expect(
        service.validatePayload(service.generateEpcPayload(buildPayload())),
        isTrue,
      );
      expect(
        service.validatePayload(service.generateRoPayPayload(buildPayload())),
        isTrue,
      );
    });
  });

  group('parseAmount', () {
    test('parses a currency prefixed amount', () {
      expect(service.parseAmount('EUR12.50', 'EUR'), 12.5);
      expect(service.parseAmount('RON100.00', 'RON'), 100.0);
    });

    test('parses a bare amount', () {
      expect(service.parseAmount('12.50', 'EUR'), 12.5);
      expect(service.parseAmount('100', 'EUR'), 100.0);
    });

    test('returns null for non positive values', () {
      expect(service.parseAmount('EUR0.00', 'EUR'), isNull);
      expect(service.parseAmount('EUR0', 'EUR'), isNull);
    });

    test('returns null for malformed values', () {
      expect(service.parseAmount('EUR-1.00', 'EUR'), isNull);
      expect(service.parseAmount('EUR1.234', 'EUR'), isNull);
      expect(service.parseAmount('abc', 'EUR'), isNull);
      expect(service.parseAmount('', 'EUR'), isNull);
    });
  });

  group('computeCrc16', () {
    test('matches the standard check value for 123456789', () {
      expect(service.computeCrc16('123456789'), '29B1');
    });

    test('returns four upper case hexadecimal digits', () {
      final String checksum = service.computeCrc16('ROPAY1');
      expect(checksum.length, 4);
      expect(checksum, checksum.toUpperCase());
    });
  });

  group('QrPaymentPayload', () {
    test('copyWith replaces the requested fields only', () {
      final QrPaymentPayload original = buildPayload();
      final QrPaymentPayload updated = original.copyWith(amount: 50.0);

      expect(updated.amount, 50.0);
      expect(updated.iban, original.iban);
      expect(updated.beneficiaryName, original.beneficiaryName);
    });

    test('toString exposes the class name and key fields', () {
      final String text = buildPayload().toString();
      expect(text, contains('QrPaymentPayload'));
      expect(text, contains('Acme SRL'));
    });
  });
}
