enum RoundUpBoundary { nearestOne, nearestFive, nearestTen }

extension RoundUpBoundaryValue on RoundUpBoundary {
  double get value {
    switch (this) {
      case RoundUpBoundary.nearestOne:
        return 1.0;
      case RoundUpBoundary.nearestFive:
        return 5.0;
      case RoundUpBoundary.nearestTen:
        return 10.0;
    }
  }
}

class RoundUpRule {
  final bool enabled;
  final RoundUpBoundary boundary;
  final int multiplier;
  final String targetVaultId;
  final double minimumTransactionThreshold;
  final bool roundExactIntegers;

  const RoundUpRule({
    this.enabled = true,
    this.boundary = RoundUpBoundary.nearestOne,
    this.multiplier = 1,
    this.targetVaultId = '',
    this.minimumTransactionThreshold = 0.0,
    this.roundExactIntegers = false,
  }) : assert(multiplier > 0, 'multiplier must be greater than zero');

  factory RoundUpRule.validated({
    bool enabled = true,
    RoundUpBoundary boundary = RoundUpBoundary.nearestOne,
    int multiplier = 1,
    String targetVaultId = '',
    double minimumTransactionThreshold = 0.0,
    bool roundExactIntegers = false,
  }) {
    if (multiplier <= 0) {
      throw ArgumentError.value(
        multiplier,
        'multiplier',
        'multiplier must be greater than zero',
      );
    }
    return RoundUpRule(
      enabled: enabled,
      boundary: boundary,
      multiplier: multiplier,
      targetVaultId: targetVaultId,
      minimumTransactionThreshold: minimumTransactionThreshold,
      roundExactIntegers: roundExactIntegers,
    );
  }

  RoundUpRule copyWith({
    bool? enabled,
    RoundUpBoundary? boundary,
    int? multiplier,
    String? targetVaultId,
    double? minimumTransactionThreshold,
    bool? roundExactIntegers,
  }) {
    return RoundUpRule(
      enabled: enabled ?? this.enabled,
      boundary: boundary ?? this.boundary,
      multiplier: multiplier ?? this.multiplier,
      targetVaultId: targetVaultId ?? this.targetVaultId,
      minimumTransactionThreshold:
          minimumTransactionThreshold ?? this.minimumTransactionThreshold,
      roundExactIntegers: roundExactIntegers ?? this.roundExactIntegers,
    );
  }
}

class RoundUpCalculation {
  final double originalAmount;
  final double roundedAmount;
  final double baseSpareChange;
  final int multiplier;
  final double finalSpareChangeTransferAmount;
  final String targetVaultId;
  final bool didTrigger;

  const RoundUpCalculation({
    required this.originalAmount,
    required this.roundedAmount,
    required this.baseSpareChange,
    required this.multiplier,
    required this.finalSpareChangeTransferAmount,
    required this.targetVaultId,
    required this.didTrigger,
  });
}

class RoundUpEngine {
  const RoundUpEngine();

  static double _round2(double v) => (v * 100).round() / 100;

  bool shouldTriggerRoundUp({
    required double transactionAmount,
    required RoundUpRule rule,
  }) {
    if (!rule.enabled) {
      return false;
    }
    if (transactionAmount <= 0) {
      return false;
    }
    if (transactionAmount < rule.minimumTransactionThreshold) {
      return false;
    }
    final RoundUpCalculation calculation = calculateRoundUp(
      transactionAmount: transactionAmount,
      rule: rule,
    );
    return calculation.baseSpareChange > 0;
  }

  RoundUpCalculation calculateRoundUp({
    required double transactionAmount,
    required RoundUpRule rule,
  }) {
    final double original = _round2(transactionAmount);

    if (!rule.enabled ||
        transactionAmount <= 0 ||
        transactionAmount < rule.minimumTransactionThreshold) {
      return RoundUpCalculation(
        originalAmount: original,
        roundedAmount: original,
        baseSpareChange: 0.0,
        multiplier: rule.multiplier,
        finalSpareChangeTransferAmount: 0.0,
        targetVaultId: rule.targetVaultId,
        didTrigger: false,
      );
    }

    final double boundary = rule.boundary.value;
    final int amountCents = (transactionAmount * 100).round();
    final int boundaryCents = (boundary * 100).round();
    final bool isExactMultiple = amountCents % boundaryCents == 0;

    int roundedCents;
    if (isExactMultiple) {
      roundedCents =
          rule.roundExactIntegers ? amountCents + boundaryCents : amountCents;
    } else {
      roundedCents =
          ((amountCents + boundaryCents - 1) ~/ boundaryCents) * boundaryCents;
    }

    final double roundedAmount = _round2(roundedCents / 100.0);
    final double baseSpareChange = _round2(roundedAmount - original);
    final double finalSpareChangeTransferAmount =
        _round2(baseSpareChange * rule.multiplier);

    return RoundUpCalculation(
      originalAmount: original,
      roundedAmount: roundedAmount,
      baseSpareChange: baseSpareChange,
      multiplier: rule.multiplier,
      finalSpareChangeTransferAmount: finalSpareChangeTransferAmount,
      targetVaultId: rule.targetVaultId,
      didTrigger: baseSpareChange > 0,
    );
  }
}
