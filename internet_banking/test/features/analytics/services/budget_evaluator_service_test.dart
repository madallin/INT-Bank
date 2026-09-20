import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/analytics/services/budget_evaluator_service.dart';

void main() {
  final BudgetEvaluatorService service = BudgetEvaluatorService();

  CategoryBudget budgetWith({
    String id = 'b1',
    BudgetCategory category = BudgetCategory.groceries,
    double monthlyLimit = 100.0,
    double currentSpent = 0.0,
    String currency = 'RON',
  }) {
    return CategoryBudget(
      id: id,
      category: category,
      monthlyLimit: monthlyLimit,
      currentSpent: currentSpent,
      currency: currency,
    );
  }

  group('BudgetThresholdStatus severity ordering', () {
    test('severity values increase from safe to overBudget', () {
      expect(BudgetThresholdStatus.safe.severity, 0);
      expect(BudgetThresholdStatus.halfConsumed.severity, 1);
      expect(BudgetThresholdStatus.warning80.severity, 2);
      expect(BudgetThresholdStatus.budgetExhausted.severity, 3);
      expect(BudgetThresholdStatus.overBudget.severity, 4);
    });

    test('each tier is strictly higher than the previous', () {
      expect(BudgetThresholdStatus.halfConsumed.severity,
          greaterThan(BudgetThresholdStatus.safe.severity));
      expect(BudgetThresholdStatus.warning80.severity,
          greaterThan(BudgetThresholdStatus.halfConsumed.severity));
      expect(BudgetThresholdStatus.budgetExhausted.severity,
          greaterThan(BudgetThresholdStatus.warning80.severity));
      expect(BudgetThresholdStatus.overBudget.severity,
          greaterThan(BudgetThresholdStatus.budgetExhausted.severity));
    });
  });

  group('determineStatus', () {
    test('stays safe below 50 percent', () {
      expect(service.determineStatus(0.0, 100.0), BudgetThresholdStatus.safe);
      expect(service.determineStatus(49.99, 100.0), BudgetThresholdStatus.safe);
    });

    test('progresses safe to halfConsumed to warning80 to budgetExhausted to overBudget',
        () {
      expect(service.determineStatus(10.0, 100.0), BudgetThresholdStatus.safe);
      expect(
          service.determineStatus(50.0, 100.0), BudgetThresholdStatus.halfConsumed);
      expect(service.determineStatus(60.0, 100.0),
          BudgetThresholdStatus.halfConsumed);
      expect(service.determineStatus(80.0, 100.0), BudgetThresholdStatus.warning80);
      expect(service.determineStatus(99.0, 100.0), BudgetThresholdStatus.warning80);
      expect(service.determineStatus(100.0, 100.0),
          BudgetThresholdStatus.budgetExhausted);
      expect(service.determineStatus(100.01, 100.0),
          BudgetThresholdStatus.overBudget);
    });

    test('exactly 50 percent returns halfConsumed', () {
      expect(service.determineStatus(25.0, 50.0), BudgetThresholdStatus.halfConsumed);
      expect(service.determineStatus(50.0, 100.0), BudgetThresholdStatus.halfConsumed);
    });

    test('exactly 80 percent returns warning80', () {
      expect(service.determineStatus(80.0, 100.0), BudgetThresholdStatus.warning80);
      expect(service.determineStatus(40.0, 50.0), BudgetThresholdStatus.warning80);
    });

    test('exactly 100 percent returns budgetExhausted', () {
      expect(service.determineStatus(100.0, 100.0),
          BudgetThresholdStatus.budgetExhausted);
      expect(service.determineStatus(250.0, 250.0),
          BudgetThresholdStatus.budgetExhausted);
    });

    test('zero limit returns safe', () {
      expect(service.determineStatus(0.0, 0.0), BudgetThresholdStatus.safe);
      expect(service.determineStatus(500.0, 0.0), BudgetThresholdStatus.safe);
    });

    test('negative limit returns safe', () {
      expect(service.determineStatus(100.0, -50.0), BudgetThresholdStatus.safe);
    });

    test('negative spend returns safe', () {
      expect(service.determineStatus(-20.0, 100.0), BudgetThresholdStatus.safe);
    });
  });

  group('evaluateTransaction threshold crossing', () {
    test('crossing 50 percent triggers halfConsumed alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 49.0),
        newExpenseAmount: 1.0,
      );

      expect(result.spentBefore, closeTo(49.0, 0.001));
      expect(result.spentAfter, closeTo(50.0, 0.001));
      expect(result.previousStatus, BudgetThresholdStatus.safe);
      expect(result.newStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.didCrossThreshold, true);
      expect(result.crossedThreshold, BudgetThresholdStatus.halfConsumed);
      expect(result.alertTitle, isNotNull);
      expect(result.alertBody, isNotNull);
      expect(result.alertTitle, contains('groceries'));
      expect(result.percentageUsed, closeTo(50.0, 0.001));
    });

    test('crossing 80 percent from 79 percent triggers warning80 alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 79.0),
        newExpenseAmount: 1.0,
      );

      expect(result.spentAfter, closeTo(80.0, 0.001));
      expect(result.previousStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.newStatus, BudgetThresholdStatus.warning80);
      expect(result.didCrossThreshold, true);
      expect(result.crossedThreshold, BudgetThresholdStatus.warning80);
      expect(result.alertTitle, isNotNull);
      expect(result.alertBody, isNotNull);
      expect(result.alertBody, contains('80.00'));
      expect(result.percentageUsed, closeTo(80.0, 0.001));
    });

    test('crossing exactly 100 percent triggers budgetExhausted alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 99.0),
        newExpenseAmount: 1.0,
      );

      expect(result.spentAfter, closeTo(100.0, 0.001));
      expect(result.newStatus, BudgetThresholdStatus.budgetExhausted);
      expect(result.didCrossThreshold, true);
      expect(result.crossedThreshold, BudgetThresholdStatus.budgetExhausted);
      expect(result.alertTitle, isNotNull);
      expect(result.alertBody, isNotNull);
      expect(result.percentageUsed, closeTo(100.0, 0.001));
    });

    test('crossing above 100 percent triggers overBudget alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 99.0),
        newExpenseAmount: 2.0,
      );

      expect(result.spentAfter, closeTo(101.0, 0.001));
      expect(result.newStatus, BudgetThresholdStatus.overBudget);
      expect(result.didCrossThreshold, true);
      expect(result.crossedThreshold, BudgetThresholdStatus.overBudget);
      expect(result.alertTitle, isNotNull);
      expect(result.alertBody, isNotNull);
      expect(result.alertBody, contains('101.00'));
    });

    test('skipping from warning80 to overBudget reports overBudget crossing', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 90.0),
        newExpenseAmount: 20.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.warning80);
      expect(result.newStatus, BudgetThresholdStatus.overBudget);
      expect(result.didCrossThreshold, true);
      expect(result.crossedThreshold, BudgetThresholdStatus.overBudget);
    });
  });

  group('evaluateTransaction no re-trigger within same tier', () {
    test('adding spend within warning80 does not re-trigger alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 80.0),
        newExpenseAmount: 5.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.warning80);
      expect(result.newStatus, BudgetThresholdStatus.warning80);
      expect(result.didCrossThreshold, false);
      expect(result.crossedThreshold, isNull);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
      expect(result.percentageUsed, closeTo(85.0, 0.001));
    });

    test('adding spend within halfConsumed does not re-trigger alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 60.0),
        newExpenseAmount: 5.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.newStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.didCrossThreshold, false);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
    });

    test('adding spend while safe does not trigger alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 10.0),
        newExpenseAmount: 5.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.safe);
      expect(result.newStatus, BudgetThresholdStatus.safe);
      expect(result.didCrossThreshold, false);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
      expect(result.percentageUsed, closeTo(15.0, 0.001));
    });

    test('spend exactly at 80 already warning80 then adding stays no alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 80.0),
        newExpenseAmount: 0.0,
      );

      expect(result.newStatus, BudgetThresholdStatus.warning80);
      expect(result.didCrossThreshold, false);
      expect(result.alertTitle, isNull);
    });
  });

  group('evaluateTransaction refunds', () {
    test('refund reduces status and does not trigger alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 90.0),
        newExpenseAmount: -20.0,
      );

      expect(result.spentBefore, closeTo(90.0, 0.001));
      expect(result.spentAfter, closeTo(70.0, 0.001));
      expect(result.previousStatus, BudgetThresholdStatus.warning80);
      expect(result.newStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.didCrossThreshold, false);
      expect(result.crossedThreshold, isNull);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
      expect(result.percentageUsed, closeTo(70.0, 0.001));
    });

    test('large refund below zero recomputes status as safe without alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 30.0),
        newExpenseAmount: -80.0,
      );

      expect(result.spentAfter, closeTo(-50.0, 0.001));
      expect(result.newStatus, BudgetThresholdStatus.safe);
      expect(result.didCrossThreshold, false);
      expect(result.crossedThreshold, isNull);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
      expect(result.percentageUsed, closeTo(-50.0, 0.001));
    });

    test('refund from overBudget back to safe does not alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 120.0),
        newExpenseAmount: -50.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.overBudget);
      expect(result.newStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.didCrossThreshold, false);
      expect(result.alertTitle, isNull);
    });
  });

  group('evaluateTransaction unbudgeted and rounding', () {
    test('zero limit returns safe with zero percentage and no alert', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(monthlyLimit: 0.0, currentSpent: 10.0),
        newExpenseAmount: 5.0,
      );

      expect(result.previousStatus, BudgetThresholdStatus.safe);
      expect(result.newStatus, BudgetThresholdStatus.safe);
      expect(result.didCrossThreshold, false);
      expect(result.alertTitle, isNull);
      expect(result.alertBody, isNull);
      expect(result.percentageUsed, closeTo(0.0, 0.001));
    });

    test('negative limit returns safe with zero percentage', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(monthlyLimit: -100.0, currentSpent: 50.0),
        newExpenseAmount: 10.0,
      );

      expect(result.newStatus, BudgetThresholdStatus.safe);
      expect(result.didCrossThreshold, false);
      expect(result.percentageUsed, closeTo(0.0, 0.001));
    });

    test('amounts are rounded to two decimal cents', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(monthlyLimit: 100.0, currentSpent: 10.129),
        newExpenseAmount: 4.111,
      );

      expect(result.spentBefore, closeTo(10.13, 0.0001));
      expect(result.spentAfter, closeTo(14.24, 0.0001));
      expect(result.percentageUsed, closeTo(14.24, 0.0001));
    });

    test('previous status uses the existing spent amount', () {
      final BudgetEvaluationResult result = service.evaluateTransaction(
        budget: budgetWith(currentSpent: 50.0),
        newExpenseAmount: 0.0,
      );

      expect(result.spentBefore, closeTo(50.0, 0.001));
      expect(result.spentAfter, closeTo(50.0, 0.001));
      expect(result.previousStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.newStatus, BudgetThresholdStatus.halfConsumed);
      expect(result.didCrossThreshold, false);
    });
  });

  group('evaluateAllCategories', () {
    test('returns one result per budget preserving order', () {
      final List<CategoryBudget> budgets = <CategoryBudget>[
        budgetWith(
            id: 'b1', category: BudgetCategory.groceries, currentSpent: 25.0),
        budgetWith(
            id: 'b2', category: BudgetCategory.utilities, currentSpent: 100.0),
        budgetWith(id: 'b3', category: BudgetCategory.dining, currentSpent: 90.0),
      ];

      final List<BudgetEvaluationResult> results =
          service.evaluateAllCategories(budgets: budgets);

      expect(results.length, 3);
      expect(results[0].category, BudgetCategory.groceries);
      expect(results[1].category, BudgetCategory.utilities);
      expect(results[2].category, BudgetCategory.dining);
    });

    test('reports current status and percentage without alerts for zero expense', () {
      final List<CategoryBudget> budgets = <CategoryBudget>[
        budgetWith(currentSpent: 50.0),
        budgetWith(
            id: 'b2',
            category: BudgetCategory.utilities,
            currentSpent: 100.0),
        budgetWith(
            id: 'b3',
            category: BudgetCategory.dining,
            currentSpent: 120.0),
      ];

      final List<BudgetEvaluationResult> results =
          service.evaluateAllCategories(budgets: budgets);

      expect(results[0].newStatus, BudgetThresholdStatus.halfConsumed);
      expect(results[0].percentageUsed, closeTo(50.0, 0.001));
      expect(results[1].newStatus, BudgetThresholdStatus.budgetExhausted);
      expect(results[1].percentageUsed, closeTo(100.0, 0.001));
      expect(results[2].newStatus, BudgetThresholdStatus.overBudget);
      expect(results[2].percentageUsed, closeTo(120.0, 0.001));

      for (final BudgetEvaluationResult result in results) {
        expect(result.didCrossThreshold, false);
        expect(result.crossedThreshold, isNull);
        expect(result.alertTitle, isNull);
        expect(result.alertBody, isNull);
      }
    });

    test('returns empty list for empty budgets', () {
      final List<BudgetEvaluationResult> results =
          service.evaluateAllCategories(budgets: <CategoryBudget>[]);
      expect(results, isEmpty);
    });

    test('handles a mix including unbudgeted category', () {
      final List<CategoryBudget> budgets = <CategoryBudget>[
        budgetWith(monthlyLimit: 0.0, currentSpent: 50.0),
        budgetWith(id: 'b2', category: BudgetCategory.health, currentSpent: 10.0),
      ];

      final List<BudgetEvaluationResult> results =
          service.evaluateAllCategories(budgets: budgets);

      expect(results.length, 2);
      expect(results[0].newStatus, BudgetThresholdStatus.safe);
      expect(results[0].percentageUsed, closeTo(0.0, 0.001));
      expect(results[1].newStatus, BudgetThresholdStatus.safe);
      expect(results[1].percentageUsed, closeTo(10.0, 0.001));
    });
  });

  group('CategoryBudget copyWith', () {
    test('copies with overrides and retains remaining fields', () {
      final CategoryBudget original = budgetWith(
        id: 'b1',
        category: BudgetCategory.groceries,
        monthlyLimit: 100.0,
        currentSpent: 20.0,
        currency: 'RON',
      );

      final CategoryBudget updated =
          original.copyWith(currentSpent: 55.0, monthlyLimit: 200.0);

      expect(updated.id, original.id);
      expect(updated.category, original.category);
      expect(updated.currency, original.currency);
      expect(updated.currentSpent, closeTo(55.0, 0.001));
      expect(updated.monthlyLimit, closeTo(200.0, 0.001));
    });

    test('copyWith with no arguments preserves all values', () {
      final CategoryBudget original = budgetWith(currentSpent: 33.33);
      final CategoryBudget copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.category, original.category);
      expect(copy.monthlyLimit, original.monthlyLimit);
      expect(copy.currency, original.currency);
      expect(copy.currentSpent, original.currentSpent);
    });
  });
}
