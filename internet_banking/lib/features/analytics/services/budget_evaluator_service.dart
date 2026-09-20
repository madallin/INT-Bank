enum BudgetCategory {
  groceries,
  utilities,
  dining,
  entertainment,
  transport,
  shopping,
  health,
  other,
}

enum BudgetThresholdStatus {
  safe,
  halfConsumed,
  warning80,
  budgetExhausted,
  overBudget,
}

extension BudgetThresholdStatusSeverity on BudgetThresholdStatus {
  int get severity {
    switch (this) {
      case BudgetThresholdStatus.safe:
        return 0;
      case BudgetThresholdStatus.halfConsumed:
        return 1;
      case BudgetThresholdStatus.warning80:
        return 2;
      case BudgetThresholdStatus.budgetExhausted:
        return 3;
      case BudgetThresholdStatus.overBudget:
        return 4;
    }
  }
}

class CategoryBudget {
  final String id;
  final BudgetCategory category;
  final double monthlyLimit;
  final String currency;
  final double currentSpent;

  const CategoryBudget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    this.currency = 'RON',
    this.currentSpent = 0.0,
  });

  CategoryBudget copyWith({
    String? id,
    BudgetCategory? category,
    double? monthlyLimit,
    String? currency,
    double? currentSpent,
  }) {
    return CategoryBudget(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      currency: currency ?? this.currency,
      currentSpent: currentSpent ?? this.currentSpent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryBudget &&
        other.id == id &&
        other.category == category &&
        other.monthlyLimit == monthlyLimit &&
        other.currency == currency &&
        other.currentSpent == currentSpent;
  }

  @override
  int get hashCode =>
      Object.hash(id, category, monthlyLimit, currency, currentSpent);

  @override
  String toString() =>
      'CategoryBudget(id: $id, category: $category, monthlyLimit: $monthlyLimit, '
      'currency: $currency, currentSpent: $currentSpent)';
}

class BudgetEvaluationResult {
  final BudgetCategory category;
  final double monthlyLimit;
  final double spentBefore;
  final double spentAfter;
  final BudgetThresholdStatus previousStatus;
  final BudgetThresholdStatus newStatus;
  final bool didCrossThreshold;
  final BudgetThresholdStatus? crossedThreshold;
  final String? alertTitle;
  final String? alertBody;
  final double percentageUsed;

  const BudgetEvaluationResult({
    required this.category,
    required this.monthlyLimit,
    required this.spentBefore,
    required this.spentAfter,
    required this.previousStatus,
    required this.newStatus,
    required this.didCrossThreshold,
    this.crossedThreshold,
    this.alertTitle,
    this.alertBody,
    required this.percentageUsed,
  });

  @override
  String toString() =>
      'BudgetEvaluationResult(category: $category, monthlyLimit: $monthlyLimit, '
      'spentBefore: $spentBefore, spentAfter: $spentAfter, '
      'previousStatus: $previousStatus, newStatus: $newStatus, '
      'didCrossThreshold: $didCrossThreshold, crossedThreshold: $crossedThreshold, '
      'percentageUsed: $percentageUsed)';
}

class BudgetEvaluatorService {
  static const double _thresholdTolerance = 0.001;

  static double _round2(double value) => (value * 100).round() / 100;

  BudgetThresholdStatus determineStatus(double spent, double limit) {
    if (limit <= 0) {
      return BudgetThresholdStatus.safe;
    }

    final double halfThreshold = limit * 0.5;
    final double warningThreshold = limit * 0.8;

    if (spent > limit + _thresholdTolerance) {
      return BudgetThresholdStatus.overBudget;
    }
    if ((spent - limit).abs() <= _thresholdTolerance) {
      return BudgetThresholdStatus.budgetExhausted;
    }
    if (spent >= warningThreshold - _thresholdTolerance) {
      return BudgetThresholdStatus.warning80;
    }
    if (spent >= halfThreshold - _thresholdTolerance) {
      return BudgetThresholdStatus.halfConsumed;
    }
    return BudgetThresholdStatus.safe;
  }

  BudgetEvaluationResult evaluateTransaction({
    required CategoryBudget budget,
    required double newExpenseAmount,
  }) {
    final double spentBefore = _round2(budget.currentSpent);
    final double spentAfter = _round2(spentBefore + newExpenseAmount);
    final double limit = budget.monthlyLimit;

    final BudgetThresholdStatus previousStatus =
        determineStatus(spentBefore, limit);
    final BudgetThresholdStatus newStatus = determineStatus(spentAfter, limit);

    final bool didCrossThreshold = newStatus.severity > previousStatus.severity;

    final double percentageUsed = limit <= 0
        ? 0.0
        : _round2(spentAfter / limit * 100);

    if (!didCrossThreshold) {
      return BudgetEvaluationResult(
        category: budget.category,
        monthlyLimit: limit,
        spentBefore: spentBefore,
        spentAfter: spentAfter,
        previousStatus: previousStatus,
        newStatus: newStatus,
        didCrossThreshold: false,
        crossedThreshold: null,
        alertTitle: null,
        alertBody: null,
        percentageUsed: percentageUsed,
      );
    }

    return BudgetEvaluationResult(
      category: budget.category,
      monthlyLimit: limit,
      spentBefore: spentBefore,
      spentAfter: spentAfter,
      previousStatus: previousStatus,
      newStatus: newStatus,
      didCrossThreshold: true,
      crossedThreshold: newStatus,
      alertTitle: _buildAlertTitle(newStatus, budget.category),
      alertBody: _buildAlertBody(
        newStatus,
        budget.category,
        percentageUsed,
        budget.currency,
      ),
      percentageUsed: percentageUsed,
    );
  }

  List<BudgetEvaluationResult> evaluateAllCategories({
    required List<CategoryBudget> budgets,
  }) {
    final List<BudgetEvaluationResult> results = <BudgetEvaluationResult>[];
    for (final CategoryBudget budget in budgets) {
      results.add(evaluateTransaction(budget: budget, newExpenseAmount: 0.0));
    }
    return results;
  }

  String _buildAlertTitle(
    BudgetThresholdStatus status,
    BudgetCategory category,
  ) {
    switch (status) {
      case BudgetThresholdStatus.halfConsumed:
        return 'Half of ${category.name} budget used';
      case BudgetThresholdStatus.warning80:
        return '${category.name} budget at 80 percent';
      case BudgetThresholdStatus.budgetExhausted:
        return '${category.name} budget exhausted';
      case BudgetThresholdStatus.overBudget:
        return '${category.name} budget exceeded';
      case BudgetThresholdStatus.safe:
        return '${category.name} budget update';
    }
  }

  String _buildAlertBody(
    BudgetThresholdStatus status,
    BudgetCategory category,
    double percentageUsed,
    String currency,
  ) {
    final String percentage = percentageUsed.toStringAsFixed(2);
    switch (status) {
      case BudgetThresholdStatus.halfConsumed:
        return 'You have used $percentage percent of your monthly '
            '${category.name} budget.';
      case BudgetThresholdStatus.warning80:
        return 'You have used $percentage percent of your monthly '
            '${category.name} budget. Approaching the limit.';
      case BudgetThresholdStatus.budgetExhausted:
        return 'You have used $percentage percent of your monthly '
            '${category.name} budget in $currency.';
      case BudgetThresholdStatus.overBudget:
        return 'You have used $percentage percent of your monthly '
            '${category.name} budget and are over the limit.';
      case BudgetThresholdStatus.safe:
        return 'You have used $percentage percent of your monthly '
            '${category.name} budget.';
    }
  }
}
