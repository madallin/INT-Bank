import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/vaults/services/savings_vault_service.dart';

double round2(double value) => (value * 100).round() / 100;

SavingsVault buildVault({
  String id = 'vault-1',
  String name = 'Vacation',
  double targetAmount = 1000.0,
  double currentAmount = 0.0,
  String currency = 'RON',
  DateTime? targetDate,
  VaultLockType lockType = VaultLockType.flexible,
  double interestRateAnnualPercent = 0.0,
  VaultStatus status = VaultStatus.active,
  DateTime? createdAt,
}) {
  return SavingsVault(
    id: id,
    name: name,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    currency: currency,
    targetDate: targetDate ?? DateTime(2026, 12, 31),
    lockType: lockType,
    interestRateAnnualPercent: interestRateAnnualPercent,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  final service = SavingsVaultService();

  group('deposit', () {
    test('increases balance and rounds to cents', () {
      final vault = buildVault(currentAmount: 10.0);
      final result = service.deposit(vault, 0.125);
      expect(result.currentAmount, closeTo(10.13, 0.001));
      expect(vault.currentAmount, closeTo(10.0, 0.001));
    });

    test('adds a normal amount without changing type identity', () {
      final vault = buildVault(currentAmount: 100.0);
      final result = service.deposit(vault, 50.55);
      expect(result.currentAmount, closeTo(150.55, 0.001));
      expect(result.id, 'vault-1');
      expect(result.status, VaultStatus.active);
    });

    test('sets status to goalReached when reaching the target', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 900.0);
      final result = service.deposit(vault, 100.0);
      expect(result.currentAmount, closeTo(1000.0, 0.001));
      expect(result.status, VaultStatus.goalReached);
    });

    test('sets status to goalReached when exceeding the target', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 950.0);
      final result = service.deposit(vault, 200.0);
      expect(result.currentAmount, closeTo(1150.0, 0.001));
      expect(result.status, VaultStatus.goalReached);
    });

    test('throws ArgumentError for zero amount', () {
      final vault = buildVault();
      expect(() => service.deposit(vault, 0.0), throwsArgumentError);
    });

    test('throws ArgumentError for negative amount', () {
      final vault = buildVault();
      expect(() => service.deposit(vault, -25.0), throwsArgumentError);
    });
  });

  group('withdraw', () {
    test('succeeds on flexible vault and reduces balance', () {
      final vault = buildVault(currentAmount: 500.0);
      final result = service.withdraw(
        vault,
        200.0,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(result.currentAmount, closeTo(300.0, 0.001));
      expect(result.status, VaultStatus.active);
    });

    test('rounds the resulting balance to cents', () {
      final vault = buildVault(currentAmount: 100.0);
      final result = service.withdraw(
        vault,
        33.335,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(result.currentAmount, closeTo(round2(100.0 - 33.335), 0.001));
    });

    test('throws InsufficientVaultBalanceException when amount exceeds balance',
        () {
      final vault = buildVault(currentAmount: 100.0);
      expect(
        () => service.withdraw(
          vault,
          200.0,
          currentDate: DateTime(2026, 6, 1),
        ),
        throwsA(isA<InsufficientVaultBalanceException>()),
      );
    });

    test('throws ArgumentError for zero amount', () {
      final vault = buildVault(currentAmount: 100.0);
      expect(
        () => service.withdraw(vault, 0.0, currentDate: DateTime(2026, 6, 1)),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative amount', () {
      final vault = buildVault(currentAmount: 100.0);
      expect(
        () => service.withdraw(vault, -10.0, currentDate: DateTime(2026, 6, 1)),
        throwsArgumentError,
      );
    });

    test('locked vault blocks normal withdrawal before target date', () {
      final vault = buildVault(
        currentAmount: 500.0,
        lockType: VaultLockType.lockedUntilDate,
        targetDate: DateTime(2026, 12, 31),
      );
      expect(
        () => service.withdraw(
          vault,
          100.0,
          currentDate: DateTime(2026, 6, 1),
        ),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('locked vault succeeds on the target date', () {
      final vault = buildVault(
        currentAmount: 500.0,
        lockType: VaultLockType.lockedUntilDate,
        targetDate: DateTime(2026, 12, 31),
      );
      final result = service.withdraw(
        vault,
        100.0,
        currentDate: DateTime(2026, 12, 31),
      );
      expect(result.currentAmount, closeTo(400.0, 0.001));
    });

    test('locked vault succeeds after the target date', () {
      final vault = buildVault(
        currentAmount: 500.0,
        lockType: VaultLockType.lockedUntilDate,
        targetDate: DateTime(2026, 12, 31),
      );
      final result = service.withdraw(
        vault,
        100.0,
        currentDate: DateTime(2027, 1, 15),
      );
      expect(result.currentAmount, closeTo(400.0, 0.001));
    });

    test('emergency break applies a 2 percent penalty and reduces balance', () {
      final vault = buildVault(
        currentAmount: 1000.0,
        lockType: VaultLockType.lockedUntilDate,
        targetDate: DateTime(2026, 12, 31),
      );
      final result = service.withdraw(
        vault,
        200.0,
        currentDate: DateTime(2026, 6, 1),
        emergencyBreakLock: true,
      );
      expect(result.currentAmount, closeTo(796.0, 0.001));
      expect(result.status, VaultStatus.active);
    });

    test('emergency break throws when withdrawal plus penalty exceeds balance',
        () {
      final vault = buildVault(
        currentAmount: 100.0,
        lockType: VaultLockType.lockedUntilDate,
        targetDate: DateTime(2026, 12, 31),
      );
      expect(
        () => service.withdraw(
          vault,
          100.0,
          currentDate: DateTime(2026, 6, 1),
          emergencyBreakLock: true,
        ),
        throwsA(isA<InsufficientVaultBalanceException>()),
      );
    });

    test('status returns to active when goalReached balance drops below target',
        () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 1000.0,
        status: VaultStatus.goalReached,
      );
      final result = service.withdraw(
        vault,
        100.0,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(result.currentAmount, closeTo(900.0, 0.001));
      expect(result.status, VaultStatus.active);
    });

    test('status stays goalReached when balance remains at target', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 1200.0,
        status: VaultStatus.goalReached,
      );
      final result = service.withdraw(
        vault,
        100.0,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(result.currentAmount, closeTo(1100.0, 0.001));
      expect(result.status, VaultStatus.goalReached);
    });
  });

  group('calculateProgressPercentage', () {
    test('returns 0 for empty vault', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 0.0);
      expect(service.calculateProgressPercentage(vault), closeTo(0.0, 0.001));
    });

    test('returns partial progress', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 250.0);
      expect(service.calculateProgressPercentage(vault), closeTo(25.0, 0.001));
    });

    test('returns exactly 100 when funded', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 1000.0);
      expect(service.calculateProgressPercentage(vault), closeTo(100.0, 0.001));
    });

    test('returns above 100 when overfunded', () {
      final vault = buildVault(targetAmount: 1000.0, currentAmount: 1500.0);
      expect(service.calculateProgressPercentage(vault), closeTo(150.0, 0.001));
    });

    test('rounds to two decimals', () {
      final vault = buildVault(targetAmount: 300.0, currentAmount: 100.0);
      expect(service.calculateProgressPercentage(vault), closeTo(33.33, 0.001));
    });

    test('returns 0 when target is non-positive', () {
      final vault = buildVault(targetAmount: 0.0, currentAmount: 100.0);
      expect(service.calculateProgressPercentage(vault), closeTo(0.0, 0.001));
    });
  });

  group('projectYield', () {
    test('compounds monthly for a known case', () {
      final vault = buildVault(
        currentAmount: 1000.0,
        interestRateAnnualPercent: 12.0,
      );
      final projection = service.projectYield(vault, monthsDuration: 12);
      final double monthlyRate = (12.0 / 100) / 12;
      final double expectedFinal =
          round2(1000.0 * math.pow(1 + monthlyRate, 12));
      final double expectedInterest = round2(expectedFinal - 1000.0);
      expect(projection.projectedFinalAmount, closeTo(1126.83, 0.001));
      expect(projection.projectedFinalAmount, closeTo(expectedFinal, 0.001));
      expect(
        projection.totalProjectedInterest,
        closeTo(expectedInterest, 0.001),
      );
      expect(projection.totalProjectedInterest, closeTo(126.83, 0.001));
    });

    test('reports the first month interest estimate', () {
      final vault = buildVault(
        currentAmount: 1000.0,
        interestRateAnnualPercent: 12.0,
      );
      final projection = service.projectYield(vault, monthsDuration: 12);
      expect(projection.monthlyInterestEstimate, closeTo(10.0, 0.001));
    });

    test('returns unchanged amount when interest rate is zero', () {
      final vault = buildVault(
        currentAmount: 750.0,
        interestRateAnnualPercent: 0.0,
      );
      final projection = service.projectYield(vault, monthsDuration: 6);
      expect(projection.projectedFinalAmount, closeTo(750.0, 0.001));
      expect(projection.totalProjectedInterest, closeTo(0.0, 0.001));
      expect(projection.monthlyInterestEstimate, closeTo(0.0, 0.001));
    });

    test('throws ArgumentError for zero months duration', () {
      final vault = buildVault(currentAmount: 1000.0);
      expect(
        () => service.projectYield(vault, monthsDuration: 0),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative months duration', () {
      final vault = buildVault(currentAmount: 1000.0);
      expect(
        () => service.projectYield(vault, monthsDuration: -3),
        throwsArgumentError,
      );
    });
  });

  group('calculateRequiredMonthlyContribution', () {
    test('spreads remaining amount across whole months', () {
      final vault = buildVault(
        targetAmount: 1200.0,
        currentAmount: 0.0,
        targetDate: DateTime(2026, 7, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(200.0, 0.001));
    });

    test('accounts for an existing balance', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 100.0,
        targetDate: DateTime(2026, 4, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(300.0, 0.001));
    });

    test('rounds up a partial month and rounds the result', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 0.0,
        targetDate: DateTime(2026, 3, 15),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(333.33, 0.001));
    });

    test('uses a minimum of one month for near term targets', () {
      final vault = buildVault(
        targetAmount: 500.0,
        currentAmount: 0.0,
        targetDate: DateTime(2026, 1, 20),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(500.0, 0.001));
    });

    test('returns zero when the vault is already funded', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 1000.0,
        targetDate: DateTime(2026, 7, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(0.0, 0.001));
    });

    test('returns zero when the vault is overfunded', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 1500.0,
        targetDate: DateTime(2026, 7, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 1, 1),
      );
      expect(contribution, closeTo(0.0, 0.001));
    });

    test('returns the full remaining amount when past due', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 200.0,
        targetDate: DateTime(2026, 1, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(contribution, closeTo(800.0, 0.001));
    });

    test('returns the full remaining amount when due on the current date', () {
      final vault = buildVault(
        targetAmount: 1000.0,
        currentAmount: 400.0,
        targetDate: DateTime(2026, 6, 1),
      );
      final contribution = service.calculateRequiredMonthlyContribution(
        vault,
        currentDate: DateTime(2026, 6, 1),
      );
      expect(contribution, closeTo(600.0, 0.001));
    });
  });
}
