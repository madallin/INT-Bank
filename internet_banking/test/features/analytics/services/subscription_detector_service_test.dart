import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/analytics/services/subscription_detector_service.dart';

RawHistoricalTransaction _tx(
  String id,
  String merchant,
  double amount,
  DateTime timestamp,
) {
  return RawHistoricalTransaction(
    id: id,
    merchantName: merchant,
    amount: amount,
    currency: 'RON',
    timestamp: timestamp,
  );
}

void main() {
  final SubscriptionDetectorService service = SubscriptionDetectorService();
  final DateTime reference = DateTime.utc(2024, 12, 31);

  group('normalizeMerchantName', () {
    test('strips trailing company and city tokens', () {
      expect(
        service.normalizeMerchantName('SPOTIFY AB STOCKHOLM'),
        'SPOTIFY',
      );
    });

    test('strips trailing store and reference numbers', () {
      expect(
        service.normalizeMerchantName('NETFLIX SERVICES 123'),
        'NETFLIX',
      );
    });

    test('strips domain and phone number', () {
      expect(
        service.normalizeMerchantName('NETFLIX.COM 866-579-7172'),
        'NETFLIX',
      );
    });

    test('strips asterisk reference codes while keeping brand words', () {
      expect(
        service.normalizeMerchantName('AMAZON PRIME*XYZ123'),
        'AMAZON PRIME',
      );
    });
  });

  group('detectSubscriptions monthly', () {
    test('detects six months of Netflix charges on the 15th', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'NETFLIX', 15.99, DateTime.utc(2024, 1, 15)),
        _tx('2', 'NETFLIX', 15.99, DateTime.utc(2024, 2, 15)),
        _tx('3', 'NETFLIX', 15.99, DateTime.utc(2024, 3, 15)),
        _tx('4', 'NETFLIX', 15.99, DateTime.utc(2024, 4, 15)),
        _tx('5', 'NETFLIX', 15.99, DateTime.utc(2024, 5, 15)),
        _tx('6', 'NETFLIX', 15.99, DateTime.utc(2024, 6, 15)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      final DetectedSubscription sub = result.first;
      expect(sub.merchantNormalizedName, 'NETFLIX');
      expect(sub.cadence, SubscriptionCadence.monthly);
      expect(sub.averageAmount, closeTo(15.99, 0.001));
      expect(sub.lastBilledAmount, closeTo(15.99, 0.001));
      expect(sub.lastBilledDate, DateTime.utc(2024, 6, 15));
      expect(sub.nextExpectedDate, DateTime.utc(2024, 7, 15));
      expect(sub.isPriceChanged, isFalse);
      expect(sub.monthlyEquivalentAmount, closeTo(15.99, 0.001));
      expect(sub.confidenceScore, greaterThan(0.0));
      expect(sub.confidenceScore, lessThanOrEqualTo(1.0));
    });

    test('tolerates weekend and holiday billing drift', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'ELECTRICITY BILL', 120.00, DateTime.utc(2024, 4, 28)),
        _tx('2', 'ELECTRICITY BILL', 120.00, DateTime.utc(2024, 5, 31)),
        _tx('3', 'ELECTRICITY BILL', 120.00, DateTime.utc(2024, 6, 30)),
        _tx('4', 'ELECTRICITY BILL', 120.00, DateTime.utc(2024, 7, 28)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.cadence, SubscriptionCadence.monthly);
    });
  });

  group('detectSubscriptions price changes', () {
    test('detects a price hike from 49.99 to 59.99', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'GYM MEMBERSHIP', 49.99, DateTime.utc(2024, 1, 10)),
        _tx('2', 'GYM MEMBERSHIP', 49.99, DateTime.utc(2024, 2, 10)),
        _tx('3', 'GYM MEMBERSHIP', 49.99, DateTime.utc(2024, 3, 10)),
        _tx('4', 'GYM MEMBERSHIP', 59.99, DateTime.utc(2024, 4, 10)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.isPriceChanged, isTrue);
      expect(result.first.averageAmount, closeTo(52.49, 0.001));
      expect(result.first.lastBilledAmount, closeTo(59.99, 0.001));
    });

    test('keeps isPriceChanged false for stable prices', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 1, 5)),
        _tx('2', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 2, 5)),
        _tx('3', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 3, 5)),
        _tx('4', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 4, 5)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.isPriceChanged, isFalse);
    });
  });

  group('detectSubscriptions cadence variants', () {
    test('detects a weekly cadence and computes monthly equivalent', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'CLEANING SERVICE', 7.00, DateTime.utc(2024, 1, 1)),
        _tx('2', 'CLEANING SERVICE', 7.00, DateTime.utc(2024, 1, 8)),
        _tx('3', 'CLEANING SERVICE', 7.00, DateTime.utc(2024, 1, 15)),
        _tx('4', 'CLEANING SERVICE', 7.00, DateTime.utc(2024, 1, 22)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.cadence, SubscriptionCadence.weekly);
      expect(result.first.monthlyEquivalentAmount, closeTo(30.42, 0.001));
      expect(result.first.nextExpectedDate, DateTime.utc(2024, 1, 29));
    });

    test('detects a quarterly cadence', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'INSURANCE POLICY', 300.00, DateTime.utc(2024, 1, 15)),
        _tx('2', 'INSURANCE POLICY', 300.00, DateTime.utc(2024, 4, 15)),
        _tx('3', 'INSURANCE POLICY', 300.00, DateTime.utc(2024, 7, 15)),
        _tx('4', 'INSURANCE POLICY', 300.00, DateTime.utc(2024, 10, 15)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.cadence, SubscriptionCadence.quarterly);
      expect(result.first.monthlyEquivalentAmount, closeTo(100.00, 0.001));
    });

    test('detects an annual cadence', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'DOMAIN RENEWAL', 120.00, DateTime.utc(2021, 6, 1)),
        _tx('2', 'DOMAIN RENEWAL', 120.00, DateTime.utc(2022, 6, 1)),
        _tx('3', 'DOMAIN RENEWAL', 120.00, DateTime.utc(2023, 6, 1)),
        _tx('4', 'DOMAIN RENEWAL', 120.00, DateTime.utc(2024, 6, 1)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 1);
      expect(result.first.cadence, SubscriptionCadence.annual);
      expect(result.first.monthlyEquivalentAmount, closeTo(10.00, 0.001));
    });
  });

  group('detectSubscriptions filtering', () {
    test('rejects a single one-off purchase', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'COFFEE SHOP', 12.50, DateTime.utc(2024, 3, 3)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result, isEmpty);
    });

    test('rejects two non recurring charges', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'ELECTRONICS STORE', 500.00, DateTime.utc(2024, 1, 3)),
        _tx('2', 'ELECTRONICS STORE', 500.00, DateTime.utc(2024, 5, 20)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result, isEmpty);
    });

    test('rejects irregular gaps as non recurring', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'RANDOM SHOP', 20.00, DateTime.utc(2024, 1, 1)),
        _tx('2', 'RANDOM SHOP', 20.00, DateTime.utc(2024, 1, 4)),
        _tx('3', 'RANDOM SHOP', 20.00, DateTime.utc(2024, 2, 18)),
        _tx('4', 'RANDOM SHOP', 20.00, DateTime.utc(2024, 3, 1)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result, isEmpty);
    });

    test('excludes negative and refund amounts', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'REFUND MERCHANT', -15.00, DateTime.utc(2024, 1, 10)),
        _tx('2', 'REFUND MERCHANT', -15.00, DateTime.utc(2024, 2, 10)),
        _tx('3', 'REFUND MERCHANT', -15.00, DateTime.utc(2024, 3, 10)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result, isEmpty);
    });
  });

  group('detectSubscriptions ordering', () {
    test('returns two subscriptions sorted by normalized merchant name', () {
      final List<RawHistoricalTransaction> history = <RawHistoricalTransaction>[
        _tx('1', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 1, 5)),
        _tx('2', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 2, 5)),
        _tx('3', 'SPOTIFY AB STOCKHOLM', 9.99, DateTime.utc(2024, 3, 5)),
        _tx('4', 'NETFLIX SERVICES 123', 15.99, DateTime.utc(2024, 1, 20)),
        _tx('5', 'NETFLIX SERVICES 123', 15.99, DateTime.utc(2024, 2, 20)),
        _tx('6', 'NETFLIX SERVICES 123', 15.99, DateTime.utc(2024, 3, 20)),
      ];

      final List<DetectedSubscription> result = service.detectSubscriptions(
        history,
        referenceDate: reference,
      );

      expect(result.length, 2);
      expect(result[0].merchantNormalizedName, 'NETFLIX');
      expect(result[1].merchantNormalizedName, 'SPOTIFY');
    });
  });

  group('summarizeCommitments', () {
    test('sums monthly equivalents and counts subscriptions', () {
      final List<DetectedSubscription> subs = <DetectedSubscription>[
        DetectedSubscription(
          merchantNormalizedName: 'A',
          cadence: SubscriptionCadence.monthly,
          averageAmount: 10.00,
          lastBilledAmount: 10.00,
          lastBilledDate: DateTime.utc(2024, 6, 1),
          nextExpectedDate: DateTime.utc(2024, 7, 1),
          isPriceChanged: false,
          confidenceScore: 0.9,
          monthlyEquivalentAmount: 10.00,
        ),
        DetectedSubscription(
          merchantNormalizedName: 'B',
          cadence: SubscriptionCadence.weekly,
          averageAmount: 7.00,
          lastBilledAmount: 7.00,
          lastBilledDate: DateTime.utc(2024, 6, 1),
          nextExpectedDate: DateTime.utc(2024, 6, 8),
          isPriceChanged: false,
          confidenceScore: 0.8,
          monthlyEquivalentAmount: 30.42,
        ),
        DetectedSubscription(
          merchantNormalizedName: 'C',
          cadence: SubscriptionCadence.annual,
          averageAmount: 60.00,
          lastBilledAmount: 60.00,
          lastBilledDate: DateTime.utc(2024, 6, 1),
          nextExpectedDate: DateTime.utc(2025, 6, 1),
          isPriceChanged: false,
          confidenceScore: 0.7,
          monthlyEquivalentAmount: 5.00,
        ),
      ];

      final RecurringCommitmentSummary summary =
          service.summarizeCommitments(subs);

      expect(summary.activeSubscriptionCount, 3);
      expect(summary.totalMonthlyEstimatedExpense, closeTo(45.42, 0.001));
      expect(summary.subscriptions, same(subs));
    });
  });
}
