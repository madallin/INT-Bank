import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/vaults/services/round_up_engine.dart';

void main() {
  const RoundUpEngine engine = RoundUpEngine();

  RoundUpCalculation calculate(
    double amount,
    RoundUpRule rule,
  ) {
    return engine.calculateRoundUp(transactionAmount: amount, rule: rule);
  }

  group('RoundUpBoundaryValue', () {
    test('exposes numeric boundary values', () {
      expect(RoundUpBoundary.nearestOne.value, 1.0);
      expect(RoundUpBoundary.nearestFive.value, 5.0);
      expect(RoundUpBoundary.nearestTen.value, 10.0);
    });
  });

  group('RoundUpRule', () {
    test('applies documented defaults', () {
      const RoundUpRule rule = RoundUpRule();
      expect(rule.enabled, isTrue);
      expect(rule.boundary, RoundUpBoundary.nearestOne);
      expect(rule.multiplier, 1);
      expect(rule.targetVaultId, '');
      expect(rule.minimumTransactionThreshold, 0.0);
      expect(rule.roundExactIntegers, isFalse);
    });

    test('copyWith overrides selected fields', () {
      const RoundUpRule rule = RoundUpRule(
        targetVaultId: 'vault-1',
        multiplier: 2,
      );
      final RoundUpRule updated = rule.copyWith(
        multiplier: 5,
        boundary: RoundUpBoundary.nearestTen,
        roundExactIntegers: true,
      );
      expect(updated.multiplier, 5);
      expect(updated.boundary, RoundUpBoundary.nearestTen);
      expect(updated.roundExactIntegers, isTrue);
      expect(updated.targetVaultId, 'vault-1');
      expect(updated.enabled, isTrue);
      expect(updated.minimumTransactionThreshold, 0.0);
    });

    test('validated throws ArgumentError for non-positive multiplier', () {
      expect(
        () => RoundUpRule.validated(multiplier: 0),
        throwsArgumentError,
      );
      expect(
        () => RoundUpRule.validated(multiplier: -3),
        throwsArgumentError,
      );
    });

    test('constructor asserts for non-positive multiplier', () {
      expect(
        () => RoundUpRule(multiplier: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('boundary increments', () {
    test('12.34 rounds up to each boundary', () {
      final RoundUpCalculation one =
          calculate(12.34, const RoundUpRule());
      expect(one.roundedAmount, closeTo(13.00, 0.001));
      expect(one.baseSpareChange, closeTo(0.66, 0.001));

      final RoundUpCalculation five = calculate(
        12.34,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(five.roundedAmount, closeTo(15.00, 0.001));
      expect(five.baseSpareChange, closeTo(2.66, 0.001));

      final RoundUpCalculation ten = calculate(
        12.34,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(ten.roundedAmount, closeTo(20.00, 0.001));
      expect(ten.baseSpareChange, closeTo(7.66, 0.001));
    });

    test('19.99 nearestOne yields exact 0.01 spare change', () {
      final RoundUpCalculation result = calculate(19.99, const RoundUpRule());
      expect(result.roundedAmount, closeTo(20.00, 0.001));
      expect(result.baseSpareChange, closeTo(0.01, 0.001));
    });

    test('50.01 rounds up to each boundary', () {
      final RoundUpCalculation one =
          calculate(50.01, const RoundUpRule());
      expect(one.roundedAmount, closeTo(51.00, 0.001));
      expect(one.baseSpareChange, closeTo(0.99, 0.001));

      final RoundUpCalculation five = calculate(
        50.01,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(five.roundedAmount, closeTo(55.00, 0.001));
      expect(five.baseSpareChange, closeTo(4.99, 0.001));

      final RoundUpCalculation ten = calculate(
        50.01,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(ten.roundedAmount, closeTo(60.00, 0.001));
      expect(ten.baseSpareChange, closeTo(9.99, 0.001));
    });

    test('0.01 nearestOne yields 0.99 spare change', () {
      final RoundUpCalculation result = calculate(0.01, const RoundUpRule());
      expect(result.roundedAmount, closeTo(1.00, 0.001));
      expect(result.baseSpareChange, closeTo(0.99, 0.001));
    });

    test('4.99 rounds up to each boundary', () {
      final RoundUpCalculation one = calculate(4.99, const RoundUpRule());
      expect(one.roundedAmount, closeTo(5.00, 0.001));
      expect(one.baseSpareChange, closeTo(0.01, 0.001));

      final RoundUpCalculation five = calculate(
        4.99,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(five.roundedAmount, closeTo(5.00, 0.001));
      expect(five.baseSpareChange, closeTo(0.01, 0.001));

      final RoundUpCalculation ten = calculate(
        4.99,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(ten.roundedAmount, closeTo(10.00, 0.001));
      expect(ten.baseSpareChange, closeTo(5.01, 0.001));
    });

    test('9.99 rounds up to each boundary', () {
      final RoundUpCalculation one = calculate(9.99, const RoundUpRule());
      expect(one.roundedAmount, closeTo(10.00, 0.001));
      expect(one.baseSpareChange, closeTo(0.01, 0.001));

      final RoundUpCalculation five = calculate(
        9.99,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(five.roundedAmount, closeTo(10.00, 0.001));
      expect(five.baseSpareChange, closeTo(0.01, 0.001));

      final RoundUpCalculation ten = calculate(
        9.99,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(ten.roundedAmount, closeTo(10.00, 0.001));
      expect(ten.baseSpareChange, closeTo(0.01, 0.001));
    });
  });

  group('exact integer handling', () {
    test('100.00 nearestOne yields no spare change by default', () {
      final RoundUpCalculation result = calculate(100.00, const RoundUpRule());
      expect(result.roundedAmount, closeTo(100.00, 0.001));
      expect(result.baseSpareChange, closeTo(0.00, 0.001));
      expect(result.didTrigger, isFalse);
    });

    test('100.00 nearestOne rounds exact integers when enabled', () {
      final RoundUpCalculation result = calculate(
        100.00,
        const RoundUpRule(roundExactIntegers: true),
      );
      expect(result.roundedAmount, closeTo(101.00, 0.001));
      expect(result.baseSpareChange, closeTo(1.00, 0.001));
      expect(result.didTrigger, isTrue);
    });

    test('100.00 nearestFive and nearestTen exact handling', () {
      final RoundUpCalculation fiveDefault = calculate(
        100.00,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(fiveDefault.baseSpareChange, closeTo(0.00, 0.001));

      final RoundUpCalculation fiveEnabled = calculate(
        100.00,
        const RoundUpRule(
          boundary: RoundUpBoundary.nearestFive,
          roundExactIntegers: true,
        ),
      );
      expect(fiveEnabled.roundedAmount, closeTo(105.00, 0.001));
      expect(fiveEnabled.baseSpareChange, closeTo(5.00, 0.001));

      final RoundUpCalculation tenDefault = calculate(
        100.00,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(tenDefault.baseSpareChange, closeTo(0.00, 0.001));

      final RoundUpCalculation tenEnabled = calculate(
        100.00,
        const RoundUpRule(
          boundary: RoundUpBoundary.nearestTen,
          roundExactIntegers: true,
        ),
      );
      expect(tenEnabled.roundedAmount, closeTo(110.00, 0.001));
      expect(tenEnabled.baseSpareChange, closeTo(10.00, 0.001));
    });

    test('5.00 exact handling for nearestOne and nearestFive', () {
      final RoundUpCalculation oneDefault =
          calculate(5.00, const RoundUpRule());
      expect(oneDefault.baseSpareChange, closeTo(0.00, 0.001));
      expect(oneDefault.didTrigger, isFalse);

      final RoundUpCalculation oneEnabled = calculate(
        5.00,
        const RoundUpRule(roundExactIntegers: true),
      );
      expect(oneEnabled.roundedAmount, closeTo(6.00, 0.001));
      expect(oneEnabled.baseSpareChange, closeTo(1.00, 0.001));

      final RoundUpCalculation fiveDefault = calculate(
        5.00,
        const RoundUpRule(boundary: RoundUpBoundary.nearestFive),
      );
      expect(fiveDefault.baseSpareChange, closeTo(0.00, 0.001));

      final RoundUpCalculation fiveEnabled = calculate(
        5.00,
        const RoundUpRule(
          boundary: RoundUpBoundary.nearestFive,
          roundExactIntegers: true,
        ),
      );
      expect(fiveEnabled.roundedAmount, closeTo(10.00, 0.001));
      expect(fiveEnabled.baseSpareChange, closeTo(5.00, 0.001));

      final RoundUpCalculation ten = calculate(
        5.00,
        const RoundUpRule(boundary: RoundUpBoundary.nearestTen),
      );
      expect(ten.roundedAmount, closeTo(10.00, 0.001));
      expect(ten.baseSpareChange, closeTo(5.00, 0.001));
    });
  });

  group('multipliers', () {
    test('scale a base spare change of 0.40', () {
      const List<int> multipliers = <int>[1, 2, 3, 5, 10];
      const List<double> expected = <double>[0.40, 0.80, 1.20, 2.00, 4.00];

      for (int i = 0; i < multipliers.length; i++) {
        final RoundUpCalculation result = calculate(
          12.60,
          RoundUpRule(multiplier: multipliers[i]),
        );
        expect(result.baseSpareChange, closeTo(0.40, 0.001));
        expect(
          result.finalSpareChangeTransferAmount,
          closeTo(expected[i], 0.001),
        );
        expect(result.multiplier, multipliers[i]);
      }
    });

    test('propagates target vault identifier', () {
      final RoundUpCalculation result = calculate(
        12.34,
        const RoundUpRule(targetVaultId: 'vault-42', multiplier: 2),
      );
      expect(result.targetVaultId, 'vault-42');
      expect(result.multiplier, 2);
      expect(result.finalSpareChangeTransferAmount, closeTo(1.32, 0.001));
    });
  });

  group('minimum transaction threshold', () {
    test('rejects amounts below the threshold', () {
      const RoundUpRule rule =
          RoundUpRule(minimumTransactionThreshold: 10.0);
      final RoundUpCalculation result = calculate(9.99, rule);
      expect(result.baseSpareChange, closeTo(0.00, 0.001));
      expect(result.finalSpareChangeTransferAmount, closeTo(0.00, 0.001));
      expect(result.didTrigger, isFalse);
      expect(engine.shouldTriggerRoundUp(transactionAmount: 9.99, rule: rule),
          isFalse);
    });

    test('accepts amounts exactly at the threshold', () {
      const RoundUpRule rule = RoundUpRule(
        minimumTransactionThreshold: 10.0,
        roundExactIntegers: true,
      );
      final RoundUpCalculation result = calculate(10.00, rule);
      expect(result.baseSpareChange, closeTo(1.00, 0.001));
      expect(result.didTrigger, isTrue);
      expect(engine.shouldTriggerRoundUp(transactionAmount: 10.00, rule: rule),
          isTrue);
    });

    test('accepts amounts above the threshold', () {
      const RoundUpRule rule =
          RoundUpRule(minimumTransactionThreshold: 10.0);
      final RoundUpCalculation result = calculate(10.01, rule);
      expect(result.baseSpareChange, closeTo(0.99, 0.001));
      expect(result.didTrigger, isTrue);
      expect(engine.shouldTriggerRoundUp(transactionAmount: 10.01, rule: rule),
          isTrue);
    });
  });

  group('zero and negative amounts', () {
    test('zero returns no spare change', () {
      final RoundUpCalculation result = calculate(0.0, const RoundUpRule());
      expect(result.roundedAmount, closeTo(0.00, 0.001));
      expect(result.baseSpareChange, closeTo(0.00, 0.001));
      expect(result.finalSpareChangeTransferAmount, closeTo(0.00, 0.001));
      expect(result.didTrigger, isFalse);
      expect(
        engine.shouldTriggerRoundUp(
          transactionAmount: 0.0,
          rule: const RoundUpRule(),
        ),
        isFalse,
      );
    });

    test('negative returns no spare change', () {
      const RoundUpRule rule = RoundUpRule(roundExactIntegers: true);
      final RoundUpCalculation result = calculate(-5.0, rule);
      expect(result.originalAmount, closeTo(-5.00, 0.001));
      expect(result.roundedAmount, closeTo(-5.00, 0.001));
      expect(result.baseSpareChange, closeTo(0.00, 0.001));
      expect(result.finalSpareChangeTransferAmount, closeTo(0.00, 0.001));
      expect(result.didTrigger, isFalse);
      expect(
        engine.shouldTriggerRoundUp(transactionAmount: -5.0, rule: rule),
        isFalse,
      );
    });
  });

  group('disabled rule', () {
    test('does not trigger and reports zero spare change', () {
      const RoundUpRule rule = RoundUpRule(enabled: false, multiplier: 5);
      final RoundUpCalculation result = calculate(12.34, rule);
      expect(result.originalAmount, closeTo(12.34, 0.001));
      expect(result.roundedAmount, closeTo(12.34, 0.001));
      expect(result.baseSpareChange, closeTo(0.00, 0.001));
      expect(result.finalSpareChangeTransferAmount, closeTo(0.00, 0.001));
      expect(result.didTrigger, isFalse);
      expect(
        engine.shouldTriggerRoundUp(
          transactionAmount: 12.34,
          rule: rule,
        ),
        isFalse,
      );
    });
  });

  group('rounding stability', () {
    test('final amounts are rounded to two decimals', () {
      const List<double> amounts = <double>[
        19.99,
        12.34,
        50.01,
        0.01,
        4.99,
        9.99,
        7.77,
      ];
      const List<RoundUpBoundary> boundaries = <RoundUpBoundary>[
        RoundUpBoundary.nearestOne,
        RoundUpBoundary.nearestFive,
        RoundUpBoundary.nearestTen,
      ];
      const List<int> multipliers = <int>[1, 2, 3, 5, 10];

      for (final double amount in amounts) {
        for (final RoundUpBoundary boundary in boundaries) {
          for (final int multiplier in multipliers) {
            final RoundUpCalculation result = calculate(
              amount,
              RoundUpRule(boundary: boundary, multiplier: multiplier),
            );
            final double base = result.baseSpareChange;
            final double finalAmount = result.finalSpareChangeTransferAmount;
            expect(base, closeTo((base * 100).round() / 100, 0.001));
            expect(
              finalAmount,
              closeTo((finalAmount * 100).round() / 100, 0.001),
            );
          }
        }
      }
    });
  });
}
