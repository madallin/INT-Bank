enum SubscriptionCadence { weekly, monthly, quarterly, annual, irregular }

extension SubscriptionCadenceInterval on SubscriptionCadence {
  int? get expectedIntervalDays {
    switch (this) {
      case SubscriptionCadence.weekly:
        return 7;
      case SubscriptionCadence.monthly:
        return 30;
      case SubscriptionCadence.quarterly:
        return 91;
      case SubscriptionCadence.annual:
        return 365;
      case SubscriptionCadence.irregular:
        return null;
    }
  }
}

class RawHistoricalTransaction {
  final String id;
  final String merchantName;
  final double amount;
  final String currency;
  final DateTime timestamp;

  const RawHistoricalTransaction({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.currency,
    required this.timestamp,
  });
}

class DetectedSubscription {
  final String merchantNormalizedName;
  final SubscriptionCadence cadence;
  final double averageAmount;
  final double lastBilledAmount;
  final DateTime lastBilledDate;
  final DateTime nextExpectedDate;
  final bool isPriceChanged;
  final double confidenceScore;
  final double monthlyEquivalentAmount;

  const DetectedSubscription({
    required this.merchantNormalizedName,
    required this.cadence,
    required this.averageAmount,
    required this.lastBilledAmount,
    required this.lastBilledDate,
    required this.nextExpectedDate,
    required this.isPriceChanged,
    required this.confidenceScore,
    required this.monthlyEquivalentAmount,
  });
}

class RecurringCommitmentSummary {
  final double totalMonthlyEstimatedExpense;
  final int activeSubscriptionCount;
  final List<DetectedSubscription> subscriptions;

  const RecurringCommitmentSummary({
    required this.totalMonthlyEstimatedExpense,
    required this.activeSubscriptionCount,
    required this.subscriptions,
  });
}

class SubscriptionDetectorService {
  static const Set<String> _noiseTokens = <String>{
    'AB',
    'SERVICE',
    'SERVICES',
    'STORE',
    'STORES',
    'INC',
    'LTD',
    'LLC',
    'ONLINE',
    'PAYMENT',
    'PURCHASE',
    'TRANSACTION',
    'TXN',
    'REF',
    'REFERENCE',
    'CARD',
    'POS',
    'DEBIT',
    'CREDIT',
    'CO',
    'COMPANY',
    'CORP',
    'GMBH',
    'BV',
    'NV',
    'AG',
    'SA',
    'SRL',
    'PLC',
    'SPA',
  };

  static const Set<String> _locationTokens = <String>{
    'STOCKHOLM',
    'LONDON',
    'DUBLIN',
    'PARIS',
    'BERLIN',
    'MADRID',
    'ROME',
    'MILAN',
    'AMSTERDAM',
    'VIENNA',
    'PRAGUE',
    'WARSAW',
    'BUCURESTI',
    'BUCHAREST',
    'CLUJ',
    'TIMISOARA',
    'BRASOV',
    'IASI',
    'CONSTANTA',
    'NEW',
    'YORK',
    'LOS',
    'ANGELES',
    'SAN',
    'FRANCISCO',
    'CHICAGO',
    'BOSTON',
    'SEATTLE',
    'AUSTIN',
    'DENVER',
    'MIAMI',
    'TORONTO',
    'SYDNEY',
    'SINGAPORE',
    'TOKYO',
    'IRELAND',
    'SWEDEN',
    'USA',
    'UK',
    'GB',
    'DE',
    'FR',
    'NL',
    'RO',
    'EU',
    'CA',
    'NY',
    'WA',
    'TX',
    'IL',
  };

  static double _round2(double v) => (v * 100).round() / 100;

  String normalizeMerchantName(String raw) {
    var value = raw.toUpperCase();

    value = value.replaceAll(RegExp(r'[*#].*$'), ' ');
    value = value.replaceAll(
      RegExp(r'\.(COM|NET|ORG|RO|IO|CO|EU|INFO|BIZ|APP|ONLINE)\b'),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\+?\d[\d\-\s]{4,}\d'), ' ');
    value = value.replaceAll(RegExp(r'\b[A-Z]*\d[A-Z0-9]*\b'), ' ');
    value = value.replaceAll(RegExp(r'\b\d+\b'), ' ');
    value = value.replaceAll(RegExp(r'[^A-Z]+'), ' ');

    final List<String> tokens = value
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList();

    final List<String> filtered = tokens
        .where((String token) => !_noiseTokens.contains(token))
        .toList();

    while (filtered.isNotEmpty &&
        _locationTokens.contains(filtered.last)) {
      filtered.removeLast();
    }

    return filtered.join(' ');
  }

  List<DetectedSubscription> detectSubscriptions(
    List<RawHistoricalTransaction> history, {
    required DateTime referenceDate,
    double intervalToleranceDays = 4.0,
  }) {
    final Map<String, List<RawHistoricalTransaction>> grouped =
        <String, List<RawHistoricalTransaction>>{};

    for (final RawHistoricalTransaction tx in history) {
      if (tx.amount <= 0) {
        continue;
      }
      final String key = normalizeMerchantName(tx.merchantName);
      if (key.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(key, () => <RawHistoricalTransaction>[]).add(tx);
    }

    final List<DetectedSubscription> results = <DetectedSubscription>[];

    for (final MapEntry<String, List<RawHistoricalTransaction>> entry
        in grouped.entries) {
      final List<RawHistoricalTransaction> charges =
          List<RawHistoricalTransaction>.from(entry.value);
      if (charges.length < 3) {
        continue;
      }

      charges.sort(
        (RawHistoricalTransaction a, RawHistoricalTransaction b) =>
            a.timestamp.compareTo(b.timestamp),
      );

      final List<double> gaps = <double>[];
      for (int i = 1; i < charges.length; i++) {
        final Duration delta =
            charges[i].timestamp.difference(charges[i - 1].timestamp);
        gaps.add(delta.inMinutes / (60.0 * 24.0));
      }

      final List<double> sortedGaps = List<double>.from(gaps)..sort();
      final double medianGap = sortedGaps.length.isOdd
          ? sortedGaps[sortedGaps.length ~/ 2]
          : (sortedGaps[sortedGaps.length ~/ 2 - 1] +
                  sortedGaps[sortedGaps.length ~/ 2]) /
              2.0;

      SubscriptionCadence? chosen;
      double chosenDistance = double.infinity;
      for (final SubscriptionCadence candidate in <SubscriptionCadence>[
        SubscriptionCadence.weekly,
        SubscriptionCadence.monthly,
        SubscriptionCadence.quarterly,
        SubscriptionCadence.annual,
      ]) {
        final int expected = candidate.expectedIntervalDays!;
        final double distance = (medianGap - expected).abs();
        if (distance <= intervalToleranceDays && distance < chosenDistance) {
          chosen = candidate;
          chosenDistance = distance;
        }
      }

      if (chosen == null) {
        continue;
      }

      final SubscriptionCadence cadence = chosen;
      final int expectedInterval = cadence.expectedIntervalDays!;

      double amountSum = 0.0;
      for (final RawHistoricalTransaction tx in charges) {
        amountSum += tx.amount;
      }
      final double averageAmount = _round2(amountSum / charges.length);

      final RawHistoricalTransaction latest = charges.last;
      final RawHistoricalTransaction previous = charges[charges.length - 2];
      final double lastBilledAmount = _round2(latest.amount);
      final bool isPriceChanged =
          (_round2(latest.amount) - _round2(previous.amount)).abs() > 0.01;

      final DateTime lastBilledDate = latest.timestamp;
      final DateTime nextExpectedDate =
          lastBilledDate.add(Duration(days: expectedInterval));

      double monthlyEquivalent;
      switch (cadence) {
        case SubscriptionCadence.weekly:
          monthlyEquivalent = averageAmount * 365.0 / 7.0 / 12.0;
          break;
        case SubscriptionCadence.monthly:
          monthlyEquivalent = averageAmount;
          break;
        case SubscriptionCadence.quarterly:
          monthlyEquivalent = averageAmount / 3.0;
          break;
        case SubscriptionCadence.annual:
          monthlyEquivalent = averageAmount / 12.0;
          break;
        case SubscriptionCadence.irregular:
          monthlyEquivalent = 0.0;
          break;
      }
      monthlyEquivalent = _round2(monthlyEquivalent);

      double deviationSum = 0.0;
      for (final double gap in gaps) {
        deviationSum += (gap - expectedInterval).abs();
      }
      final double averageDeviation = deviationSum / gaps.length;
      final double proximity =
          (1.0 - (averageDeviation / intervalToleranceDays))
              .clamp(0.0, 1.0)
              .toDouble();
      final double sampleWeight = gaps.length / (gaps.length + 2.0);
      final double confidenceScore =
          (0.6 * proximity + 0.4 * sampleWeight).clamp(0.0, 1.0).toDouble();

      results.add(
        DetectedSubscription(
          merchantNormalizedName: entry.key,
          cadence: cadence,
          averageAmount: averageAmount,
          lastBilledAmount: lastBilledAmount,
          lastBilledDate: lastBilledDate,
          nextExpectedDate: nextExpectedDate,
          isPriceChanged: isPriceChanged,
          confidenceScore: confidenceScore,
          monthlyEquivalentAmount: monthlyEquivalent,
        ),
      );
    }

    results.sort(
      (DetectedSubscription a, DetectedSubscription b) =>
          a.merchantNormalizedName.compareTo(b.merchantNormalizedName),
    );

    return results;
  }

  RecurringCommitmentSummary summarizeCommitments(
    List<DetectedSubscription> subscriptions,
  ) {
    double total = 0.0;
    for (final DetectedSubscription subscription in subscriptions) {
      total += subscription.monthlyEquivalentAmount;
    }
    return RecurringCommitmentSummary(
      totalMonthlyEstimatedExpense: _round2(total),
      activeSubscriptionCount: subscriptions.length,
      subscriptions: subscriptions,
    );
  }
}
