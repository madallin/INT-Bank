import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/formatters.dart';

void main() {
  group('formatAmount', () {
    test('uses Romanian separators', () {
      expect(formatAmount(0), '0,00');
      expect(formatAmount(12.5), '12,50');
      expect(formatAmount(1234.56), '1.234,56');
      expect(formatAmount(1234567.891), '1.234.567,89');
    });

    test('handles signs', () {
      expect(formatAmount(-1234.5), '-1.234,50');
      expect(formatAmount(10, showSign: true), '+10,00');
      expect(formatAmount(-10, showSign: true), '-10,00');
      expect(formatAmount(0, showSign: true), '0,00');
    });

    test('does not print a sign for values that round to zero', () {
      expect(formatAmount(-0.001), '0,00');
    });

    test('supports other precisions', () {
      expect(formatAmount(1500, decimals: 0), '1.500');
      expect(formatRate(4.97123), '4,9712');
      expect(formatPercent(12.345), '12,3%');
    });
  });

  group('formatMoney', () {
    test('appends the currency', () {
      expect(formatMoney(1234.5, 'EUR'), '1.234,50 EUR');
      expect(formatMoney(-3, 'RON', showSign: true), '-3,00 RON');
      expect(formatMoney(3, 'RON', showSign: true), '+3,00 RON');
    });

    test('masks for privacy mode', () {
      expect(maskedMoney('RON'), '•••• RON');
    });
  });

  group('dates', () {
    test('formats calendar dates', () {
      expect(formatDate(DateTime(2026, 3, 7)), '07.03.2026');
      expect(formatDateTime(DateTime(2026, 3, 7, 9, 5)), '07.03.2026, 09:05');
      expect(formatApiDate(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('formats server timestamps and keeps unparseable text', () {
      expect(formatIsoDate('2026-03-07T09:05:00'), '07.03.2026');
      expect(formatIsoDate('2026-03-07T09:05:00', withTime: true),
          '07.03.2026, 09:05');
      expect(formatIsoDate('ieri'), 'ieri');
      expect(formatIsoDate(null), '');
    });
  });

  group('grouping', () {
    test('groups IBANs and card numbers in fours', () {
      expect(formatIban('ro49intb0001ron0000000001'),
          'RO49 INTB 0001 RON0 0000 0000 1');
      expect(groupInFours('4111 1111 11111111'), '4111 1111 1111 1111');
    });
  });
}
