import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/helpers.dart';
import 'package:internet_banking/core/utils/input_formatters.dart';

/// Simulates typing [keys] one character at a time into an empty field.
String typeKeys(String keys) {
  final formatter = AmountInputFormatter();
  var value = TextEditingValue.empty;
  for (final key in keys.split('')) {
    final next = TextEditingValue(
      text: value.text + key,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    value = formatter.formatEditUpdate(value, next);
  }
  return value.text;
}

String paste(String text) => AmountInputFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
    .text;

String deleteLast(String text) {
  final old = TextEditingValue(text: text);
  return AmountInputFormatter()
      .formatEditUpdate(
          old, TextEditingValue(text: text.substring(0, text.length - 1)))
      .text;
}

void main() {
  group('AmountInputFormatter', () {
    test('groups thousands with dots while typing', () {
      expect(typeKeys('1234'), '1.234');
      expect(typeKeys('1234567'), '1.234.567');
    });

    test('accepts comma as the decimal separator', () {
      expect(typeKeys('1234,5'), '1.234,5');
      expect(typeKeys('1234,56'), '1.234,56');
    });

    test('treats a typed dot as the decimal separator', () {
      expect(typeKeys('12.5'), '12,5');
      expect(typeKeys('1234.56'), '1.234,56');
    });

    test('limits decimals to two digits', () {
      expect(typeKeys('12,345'), '12,34');
    });

    test('keeps a single decimal separator', () {
      expect(typeKeys('12,5,6'), '12,56');
      expect(typeKeys('12,5.6'), '12,56');
    });

    test('prefixes a leading separator with zero', () {
      expect(typeKeys(',5'), '0,5');
    });

    test('drops leading zeros', () {
      expect(typeKeys('0012'), '12');
    });

    test('reads pasted dot-decimal amounts as decimals', () {
      expect(paste('12.50'), '12,50');
      expect(paste('1.234,56'), '1.234,56');
      expect(paste('1.234'), '1.234');
    });

    test('deleting a digit regroups instead of creating decimals', () {
      expect(deleteLast('12.345'), '1.234');
    });

    test('ignores letters and other symbols', () {
      expect(paste('RON 1 234,5x'), '1.234,5');
    });

    test('rejects amounts above the integer digit limit', () {
      final formatter = AmountInputFormatter(maxIntegerDigits: 3);
      const old = TextEditingValue(text: '123');
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: '1234')),
        old,
      );
    });
  });

  group('parseAmount on formatted amounts', () {
    test('parses grouped amounts with decimals', () {
      expect(parseAmount('1.234,56'), 1234.56);
    });

    test('parses an amount with a trailing comma', () {
      expect(parseAmount('12,'), 12.0);
    });

    test('returns null for empty input', () {
      expect(parseAmount(''), isNull);
    });
  });
}
