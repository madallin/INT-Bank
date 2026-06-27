import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/validators.dart';

void main() {
  group('Validators.validateIBAN', () {
    test('returns error for null value', () {
      expect(Validators.validateIBAN(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(Validators.validateIBAN(''), isNotNull);
    });

    test('returns null for valid IBAN', () {
      expect(Validators.validateIBAN('RO49AAAA1B31007593840000'), isNull);
    });

    test('returns error for too short IBAN', () {
      expect(Validators.validateIBAN('RO12'), isNotNull);
    });

    test('accepts IBAN with spaces', () {
      expect(Validators.validateIBAN('RO49 AAAA 1B31 0075 9384 0000'), isNull);
    });
  });

  group('Validators.validateEmail', () {
    test('returns error for null value', () {
      expect(Validators.validateEmail(null), isNotNull);
    });

    test('returns null for valid email', () {
      expect(Validators.validateEmail('user@example.com'), isNull);
    });

    test('returns error for invalid email', () {
      expect(Validators.validateEmail('not-an-email'), isNotNull);
    });
  });

  group('Validators.validatePhone', () {
    test('returns error for null value', () {
      expect(Validators.validatePhone(null), isNotNull);
    });

    test('returns null for valid phone', () {
      expect(Validators.validatePhone('0712345678'), isNull);
    });
  });

  group('Validators.validatePin', () {
    test('returns error for null value', () {
      expect(Validators.validatePin(null), isNotNull);
    });

    test('returns null for valid 6-digit PIN', () {
      expect(Validators.validatePin('123456'), isNull);
    });

    test('returns error for short PIN', () {
      expect(Validators.validatePin('123'), isNotNull);
    });

    test('returns error for non-digit PIN', () {
      expect(Validators.validatePin('abcdef'), isNotNull);
    });
  });

  group('Validators.validateCardNumber', () {
    test('returns error for null value', () {
      expect(Validators.validateCardNumber(null), isNotNull);
    });

    test('returns null for valid 16-digit card number', () {
      expect(Validators.validateCardNumber('1234567890123456'), isNull);
    });

    test('accepts card number with spaces', () {
      expect(Validators.validateCardNumber('1234 5678 9012 3456'), isNull);
    });

    test('returns error for non-digit characters', () {
      expect(Validators.validateCardNumber('123456789012345a'), isNotNull);
    });
  });

  group('Validators.validateCNP', () {
    test('returns error for null value', () {
      expect(Validators.validateCNP(null), isNotNull);
    });

    test('returns null for valid 13-digit CNP', () {
      expect(Validators.validateCNP('1234567890123'), isNull);
    });

    test('returns error for wrong length', () {
      expect(Validators.validateCNP('12345'), isNotNull);
    });
  });

  group('Validators.validatePassword', () {
    test('returns error for null value', () {
      expect(Validators.validatePassword(null), isNotNull);
    });

    test('returns null for password with 6+ chars', () {
      expect(Validators.validatePassword('pass12'), isNull);
    });

    test('returns error for short password', () {
      expect(Validators.validatePassword('abc'), isNotNull);
    });
  });

  group('Validators.validateRequired', () {
    test('returns error for null value', () {
      expect(Validators.validateRequired(null), isNotNull);
    });

    test('returns null for non-empty value', () {
      expect(Validators.validateRequired('hello'), isNull);
    });

    test('returns error for whitespace-only', () {
      expect(Validators.validateRequired('   '), isNotNull);
    });
  });

  group('Validators.validateAmount', () {
    test('returns error for null value', () {
      expect(Validators.validateAmount(null), isNotNull);
    });

    test('returns null for valid positive amount', () {
      expect(Validators.validateAmount('100'), isNull);
    });

    test('returns error for zero', () {
      expect(Validators.validateAmount('0'), isNotNull);
    });

    test('accepts decimal amounts', () {
      expect(Validators.validateAmount('150.50'), isNull);
    });
  });

  group('Validators.validateName', () {
    test('returns error for null value', () {
      expect(Validators.validateName(null), isNotNull);
    });

    test('returns null for valid full name', () {
      expect(Validators.validateName('John Doe'), isNull);
    });

    test('returns error for single name', () {
      expect(Validators.validateName('John'), isNotNull);
    });
  });
}
