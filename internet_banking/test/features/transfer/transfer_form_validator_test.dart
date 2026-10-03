import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/transfer_form_validator.dart';

void main() {
  group('TransferFormValidator.iban', () {
    test('accepts valid external IBANs from Romania and abroad', () {
      expect(TransferFormValidator.iban('RO49 AAAA 1B31 0075 9384 0000'), isNull);
      expect(TransferFormValidator.iban('DE89370400440532013000'), isNull);
      expect(TransferFormValidator.iban('gb82 west 1234 5698 7654 32'), isNull);
    });

    test('rejects typos through the checksum', () {
      // Last digit changed.
      expect(TransferFormValidator.iban('RO49AAAA1B31007593840001'), isNotNull);
      expect(TransferFormValidator.iban('DE89370400440532013001'), isNotNull);
    });

    test('explains a wrong Romanian length', () {
      expect(TransferFormValidator.iban('RO49AAAA1B3100759384'), contains('24 de caractere'));
    });

    test('accepts INT Bank IBANs the backend issues today', () {
      // Primary account (20 chars) and currency sub-account (fixed check value).
      expect(TransferFormValidator.iban('RO57INTB1234RON12345'), isNull);
      expect(TransferFormValidator.iban('RO49INTB0001EUR3F9A01BC'), isNull);
      expect(TransferFormValidator.isInternalIban('RO49INTB0001EUR3F9A01BC'), isTrue);
      expect(TransferFormValidator.isInternalIban('RO49AAAA1B31007593840000'), isFalse);
    });

    test('rejects malformed input and the source account', () {
      expect(TransferFormValidator.iban(''), isNotNull);
      expect(TransferFormValidator.iban('49RO1234'), isNotNull);
      expect(TransferFormValidator.iban('RO49'), isNotNull);
      expect(
        TransferFormValidator.iban('RO49INTB0001EUR3F9A01BC', ownIban: 'ro49 intb 0001 eur3 f9a0 1bc'),
        contains('contul din care plătești'),
      );
    });
  });

  group('other fields', () {
    test('beneficiary name allows companies and diacritics', () {
      expect(TransferFormValidator.beneficiaryName('ENGIE'), isNull);
      expect(TransferFormValidator.beneficiaryName('Ștefan Țurcanu'), isNull);
      expect(TransferFormValidator.beneficiaryName(' '), isNotNull);
      expect(TransferFormValidator.beneficiaryName('12345'), isNotNull);
      expect(TransferFormValidator.beneficiaryName('a' * 71), isNotNull);
    });

    test('amount must be positive and within the balance', () {
      expect(TransferFormValidator.amount(null), isNotNull);
      expect(TransferFormValidator.amount(0), isNotNull);
      expect(TransferFormValidator.amount(10.5), isNull);
      expect(TransferFormValidator.amount(10.5, available: 10.49), contains('10,49 RON'));
      expect(TransferFormValidator.amount(10.49, available: 10.49), isNull);
    });

    test('reason is required and bounded', () {
      expect(TransferFormValidator.reason(''), isNotNull);
      expect(TransferFormValidator.reason('ab'), isNotNull);
      expect(TransferFormValidator.reason('Chirie'), isNull);
      expect(TransferFormValidator.reason('x' * 141), isNotNull);
    });
  });
}
