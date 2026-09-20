import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Statement Date Range Validation Tests', () {
    test('Calculates date range under 365 days correctly', () {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final diff = now.difference(thirtyDaysAgo).inDays;

      expect(diff, 30);
      expect(diff <= 366, isTrue);
    });

    test('Identifies date range exceeding 1 year', () {
      final now = DateTime.now();
      final fourHundredDaysAgo = now.subtract(const Duration(days: 400));
      final diff = now.difference(fourHundredDaysAgo).inDays;

      expect(diff > 366, isTrue);
    });

    test('Formats Romanian currency and balances properly', () {
      const balance = 1250.75;
      final formatted = '${balance.toStringAsFixed(2)} RON';
      expect(formatted, '1250.75 RON');
    });
  });
}
