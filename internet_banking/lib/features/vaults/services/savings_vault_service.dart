import 'dart:math' as math;

enum VaultLockType { flexible, lockedUntilDate }

enum VaultStatus { active, goalReached, closed }

class SavingsVault {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final DateTime targetDate;
  final VaultLockType lockType;
  final double interestRateAnnualPercent;
  final VaultStatus status;
  final DateTime createdAt;

  const SavingsVault({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.currency = 'RON',
    required this.targetDate,
    this.lockType = VaultLockType.flexible,
    this.interestRateAnnualPercent = 0.0,
    this.status = VaultStatus.active,
    required this.createdAt,
  });

  SavingsVault copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? currency,
    DateTime? targetDate,
    VaultLockType? lockType,
    double? interestRateAnnualPercent,
    VaultStatus? status,
    DateTime? createdAt,
  }) {
    return SavingsVault(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      lockType: lockType ?? this.lockType,
      interestRateAnnualPercent:
          interestRateAnnualPercent ?? this.interestRateAnnualPercent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavingsVault &&
        other.id == id &&
        other.name == name &&
        other.targetAmount == targetAmount &&
        other.currentAmount == currentAmount &&
        other.currency == currency &&
        other.targetDate == targetDate &&
        other.lockType == lockType &&
        other.interestRateAnnualPercent == interestRateAnnualPercent &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        targetAmount,
        currentAmount,
        currency,
        targetDate,
        lockType,
        interestRateAnnualPercent,
        status,
        createdAt,
      );

  @override
  String toString() =>
      'SavingsVault(id: $id, name: $name, currentAmount: $currentAmount, '
      'targetAmount: $targetAmount, status: $status)';
}

class VaultYieldProjection {
  final double totalProjectedInterest;
  final double monthlyInterestEstimate;
  final double projectedFinalAmount;

  const VaultYieldProjection({
    required this.totalProjectedInterest,
    required this.monthlyInterestEstimate,
    required this.projectedFinalAmount,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultYieldProjection &&
        other.totalProjectedInterest == totalProjectedInterest &&
        other.monthlyInterestEstimate == monthlyInterestEstimate &&
        other.projectedFinalAmount == projectedFinalAmount;
  }

  @override
  int get hashCode => Object.hash(
        totalProjectedInterest,
        monthlyInterestEstimate,
        projectedFinalAmount,
      );
}

class InsufficientVaultBalanceException implements Exception {
  final String message;

  InsufficientVaultBalanceException([
    this.message = 'Insufficient vault balance for this operation.',
  ]);

  @override
  String toString() => 'InsufficientVaultBalanceException: $message';
}

class VaultLockedException implements Exception {
  final String message;

  VaultLockedException([
    this.message = 'Vault is locked until the target date.',
  ]);

  @override
  String toString() => 'VaultLockedException: $message';
}

class SavingsVaultService {
  static const double emergencyWithdrawalPenaltyRate = 0.02;

  static double _round2(double value) => (value * 100).round() / 100;

  SavingsVault deposit(SavingsVault vault, double amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Deposit amount must be positive.');
    }
    final double newBalance = _round2(vault.currentAmount + amount);
    final VaultStatus newStatus =
        newBalance >= vault.targetAmount ? VaultStatus.goalReached : vault.status;
    return vault.copyWith(currentAmount: newBalance, status: newStatus);
  }

  SavingsVault withdraw(
    SavingsVault vault,
    double amount, {
    required DateTime currentDate,
    bool emergencyBreakLock = false,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Withdrawal amount must be positive.');
    }

    final bool lockActive = vault.lockType == VaultLockType.lockedUntilDate &&
        currentDate.isBefore(vault.targetDate);

    if (lockActive && !emergencyBreakLock) {
      throw VaultLockedException(
        'Vault ${vault.id} is locked until ${vault.targetDate.toIso8601String()}.',
      );
    }

    if (amount > vault.currentAmount) {
      throw InsufficientVaultBalanceException(
        'Cannot withdraw $amount from a balance of ${vault.currentAmount}.',
      );
    }

    double penalty = 0.0;
    if (lockActive && emergencyBreakLock) {
      penalty = _round2(amount * emergencyWithdrawalPenaltyRate);
    }

    final double newBalance = _round2(vault.currentAmount - amount - penalty);
    if (newBalance < 0) {
      throw InsufficientVaultBalanceException(
        'Withdrawal plus penalty exceeds the available balance of ${vault.currentAmount}.',
      );
    }

    VaultStatus newStatus = vault.status;
    if (vault.status == VaultStatus.goalReached && newBalance < vault.targetAmount) {
      newStatus = VaultStatus.active;
    }

    return vault.copyWith(currentAmount: newBalance, status: newStatus);
  }

  double calculateProgressPercentage(SavingsVault vault) {
    if (vault.targetAmount <= 0) return 0.0;
    return _round2((vault.currentAmount / vault.targetAmount) * 100);
  }

  VaultYieldProjection projectYield(
    SavingsVault vault, {
    required int monthsDuration,
  }) {
    if (monthsDuration <= 0) {
      throw ArgumentError.value(
        monthsDuration,
        'monthsDuration',
        'monthsDuration must be greater than zero.',
      );
    }

    final double monthlyRate = (vault.interestRateAnnualPercent / 100) / 12;
    final double projectedFinalAmount = _round2(
      vault.currentAmount * math.pow(1 + monthlyRate, monthsDuration),
    );
    final double totalProjectedInterest =
        _round2(projectedFinalAmount - vault.currentAmount);
    final double monthlyInterestEstimate =
        _round2(vault.currentAmount * monthlyRate);

    return VaultYieldProjection(
      totalProjectedInterest: totalProjectedInterest,
      monthlyInterestEstimate: monthlyInterestEstimate,
      projectedFinalAmount: projectedFinalAmount,
    );
  }

  double calculateRequiredMonthlyContribution(
    SavingsVault vault, {
    required DateTime currentDate,
  }) {
    final double remaining = vault.targetAmount - vault.currentAmount;
    if (remaining <= 0) return 0.0;

    if (!currentDate.isBefore(vault.targetDate)) {
      return _round2(remaining);
    }

    int months = (vault.targetDate.year - currentDate.year) * 12 +
        (vault.targetDate.month - currentDate.month);
    if (vault.targetDate.day > currentDate.day) {
      months += 1;
    }
    if (months < 1) {
      months = 1;
    }

    return _round2(remaining / months);
  }
}
