import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/cards/services/transaction_dispute_service.dart';

void main() {
  const TransactionDisputeService service = TransactionDisputeService();
  final DateTime now = DateTime.utc(2026, 6, 15, 12, 0, 0);
  final DateTime transactionDate = DateTime.utc(2026, 6, 1, 8, 30, 0);

  DisputeTicket openFor(DisputeReason reason) {
    return service.openDispute(
      transactionId: 'txn-1',
      reason: reason,
      transactionDate: transactionDate,
      now: now,
    );
  }

  group('openDispute reason codes', () {
    test('maps every reason code into the ticket', () {
      for (final DisputeReason reason in DisputeReason.values) {
        final DisputeTicket ticket = openFor(reason);
        expect(ticket.reason, reason);
        expect(ticket.transactionId, 'txn-1');
        expect(ticket.status, DisputeStatus.submitted);
        expect(ticket.openedAt, now);
        expect(ticket.updatedAt, now);
      }
    });

    test('accepts all five reason codes', () {
      expect(DisputeReason.values.length, 5);
    });
  });

  group('checkEligibility 120 day window', () {
    test('day 119 is eligible and not expired', () {
      final DateTime date = now.subtract(const Duration(days: 119));
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: now);
      expect(result.daysSinceTransaction, 119);
      expect(result.isEligible, isTrue);
      expect(result.isExpired, isFalse);
    });

    test('exactly 120 days is still eligible', () {
      final DateTime date = now.subtract(const Duration(days: 120));
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: now);
      expect(result.daysSinceTransaction, 120);
      expect(result.isEligible, isTrue);
      expect(result.isExpired, isFalse);
    });

    test('day 121 is expired and ineligible', () {
      final DateTime date = now.subtract(const Duration(days: 121));
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: now);
      expect(result.daysSinceTransaction, 121);
      expect(result.isEligible, isFalse);
      expect(result.isExpired, isTrue);
    });

    test('openDispute throws on day 121', () {
      expect(
        () => service.openDispute(
          transactionId: 'txn-1',
          reason: DisputeReason.duplicateCharge,
          transactionDate: now.subtract(const Duration(days: 121)),
          now: now,
        ),
        throwsStateError,
      );
    });

    test('openDispute succeeds exactly on day 120', () {
      final DisputeTicket ticket = service.openDispute(
        transactionId: 'txn-1',
        reason: DisputeReason.duplicateCharge,
        transactionDate: now.subtract(const Duration(days: 120)),
        now: now,
      );
      expect(ticket.status, DisputeStatus.submitted);
    });

    test('counts whole UTC calendar days', () {
      final DateTime date = DateTime.utc(2026, 6, 14, 23, 0, 0);
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: now);
      expect(result.daysSinceTransaction, 1);
      expect(result.isEligible, isTrue);
    });

    test('partial days do not inflate the day count past the window', () {
      final DateTime date = DateTime.utc(2026, 2, 15, 23, 0, 0);
      final DateTime boundaryNow = DateTime.utc(2026, 6, 15, 1, 0, 0);
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: boundaryNow);
      expect(result.daysSinceTransaction, 120);
      expect(result.isExpired, isFalse);
      expect(result.isEligible, isTrue);
    });
  });

  group('checkEligibility future transactions', () {
    test('a future transaction is ineligible and not expired', () {
      final DateTime date = now.add(const Duration(days: 3));
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: date, now: now);
      expect(result.daysSinceTransaction < 0, isTrue);
      expect(result.isEligible, isFalse);
      expect(result.isExpired, isFalse);
    });

    test('openDispute throws for a future transaction', () {
      expect(
        () => service.openDispute(
          transactionId: 'txn-1',
          reason: DisputeReason.goodsNotReceived,
          transactionDate: now.add(const Duration(days: 3)),
          now: now,
        ),
        throwsStateError,
      );
    });
  });

  group('shouldSuggestCardFreeze', () {
    test('is true only for unrecognizedTransaction', () {
      for (final DisputeReason reason in DisputeReason.values) {
        final DisputeEligibility result = service.checkEligibility(
          transactionDate: transactionDate,
          now: now,
          reason: reason,
        );
        expect(
          result.shouldSuggestCardFreeze,
          reason == DisputeReason.unrecognizedTransaction,
          reason: 'reason $reason',
        );
      }
    });

    test('is false when no reason is supplied', () {
      final DisputeEligibility result =
          service.checkEligibility(transactionDate: transactionDate, now: now);
      expect(result.shouldSuggestCardFreeze, isFalse);
    });

    test('ticket mirrors the freeze suggestion', () {
      expect(
        openFor(DisputeReason.unrecognizedTransaction).isCardFrozenSuggested,
        isTrue,
      );
      expect(
        openFor(DisputeReason.atmCashNotDispensed).isCardFrozenSuggested,
        isFalse,
      );
    });
  });

  group('canTransition graph', () {
    test('submitted allows underReview and rejected only', () {
      expect(
        service.canTransition(DisputeStatus.submitted, DisputeStatus.underReview),
        isTrue,
      );
      expect(
        service.canTransition(DisputeStatus.submitted, DisputeStatus.rejected),
        isTrue,
      );
      expect(
        service.canTransition(
          DisputeStatus.submitted,
          DisputeStatus.provisionalCreditIssued,
        ),
        isFalse,
      );
      expect(
        service.canTransition(DisputeStatus.submitted, DisputeStatus.resolved),
        isFalse,
      );
    });

    test('underReview allows provisionalCreditIssued and rejected only', () {
      expect(
        service.canTransition(
          DisputeStatus.underReview,
          DisputeStatus.provisionalCreditIssued,
        ),
        isTrue,
      );
      expect(
        service.canTransition(DisputeStatus.underReview, DisputeStatus.rejected),
        isTrue,
      );
      expect(
        service.canTransition(DisputeStatus.underReview, DisputeStatus.resolved),
        isFalse,
      );
      expect(
        service.canTransition(DisputeStatus.underReview, DisputeStatus.submitted),
        isFalse,
      );
    });

    test('provisionalCreditIssued allows resolved and rejected only', () {
      expect(
        service.canTransition(
          DisputeStatus.provisionalCreditIssued,
          DisputeStatus.resolved,
        ),
        isTrue,
      );
      expect(
        service.canTransition(
          DisputeStatus.provisionalCreditIssued,
          DisputeStatus.rejected,
        ),
        isTrue,
      );
      expect(
        service.canTransition(
          DisputeStatus.provisionalCreditIssued,
          DisputeStatus.underReview,
        ),
        isFalse,
      );
    });

    test('terminal states allow no transition', () {
      for (final DisputeStatus to in DisputeStatus.values) {
        expect(service.canTransition(DisputeStatus.resolved, to), isFalse);
        expect(service.canTransition(DisputeStatus.rejected, to), isFalse);
      }
    });
  });

  group('transition lifecycle', () {
    test('walks the full resolution path', () {
      final DisputeTicket opened = openFor(DisputeReason.duplicateCharge);
      final DisputeTicket reviewing = service.transition(
        opened,
        DisputeStatus.underReview,
        now: now.add(const Duration(days: 1)),
      );
      expect(reviewing.status, DisputeStatus.underReview);
      expect(reviewing.updatedAt, now.add(const Duration(days: 1)));
      expect(reviewing.openedAt, opened.openedAt);

      final DisputeTicket credit = service.transition(
        reviewing,
        DisputeStatus.provisionalCreditIssued,
        now: now.add(const Duration(days: 2)),
      );
      expect(credit.status, DisputeStatus.provisionalCreditIssued);

      final DisputeTicket resolved = service.transition(
        credit,
        DisputeStatus.resolved,
        now: now.add(const Duration(days: 3)),
      );
      expect(resolved.status, DisputeStatus.resolved);
      expect(resolved.updatedAt, now.add(const Duration(days: 3)));
    });

    test('walks the rejection path from submitted', () {
      final DisputeTicket rejected = service.transition(
        openFor(DisputeReason.incorrectAmount),
        DisputeStatus.rejected,
        now: now.add(const Duration(days: 1)),
      );
      expect(rejected.status, DisputeStatus.rejected);
    });

    test('walks the rejection path from provisional credit', () {
      final DisputeTicket opened = openFor(DisputeReason.goodsNotReceived);
      final DisputeTicket reviewing = service.transition(
        opened,
        DisputeStatus.underReview,
        now: now,
      );
      final DisputeTicket credit = service.transition(
        reviewing,
        DisputeStatus.provisionalCreditIssued,
        now: now,
      );
      final DisputeTicket rejected = service.transition(
        credit,
        DisputeStatus.rejected,
        now: now,
      );
      expect(rejected.status, DisputeStatus.rejected);
    });

    test('rejects skipping states', () {
      final DisputeTicket opened = openFor(DisputeReason.duplicateCharge);
      expect(
        () => service.transition(
          opened,
          DisputeStatus.provisionalCreditIssued,
          now: now,
        ),
        throwsStateError,
      );
      expect(
        () =>
            service.transition(opened, DisputeStatus.resolved, now: now),
        throwsStateError,
      );
    });

    test('rejects transitions out of terminal states', () {
      final DisputeTicket opened = openFor(DisputeReason.incorrectAmount);
      final DisputeTicket resolved = service.transition(
        service.transition(
          service.transition(
            opened,
            DisputeStatus.underReview,
            now: now,
          ),
          DisputeStatus.provisionalCreditIssued,
          now: now,
        ),
        DisputeStatus.resolved,
        now: now,
      );
      expect(
        () => service.transition(
          resolved,
          DisputeStatus.underReview,
          now: now,
        ),
        throwsStateError,
      );

      final DisputeTicket rejected = service.transition(
        opened,
        DisputeStatus.rejected,
        now: now,
      );
      expect(
        () => service.transition(
          rejected,
          DisputeStatus.underReview,
          now: now,
        ),
        throwsStateError,
      );
    });

    test('leaves the ticket unchanged on an invalid transition', () {
      final DisputeTicket opened = openFor(DisputeReason.duplicateCharge);
      try {
        service.transition(
          opened,
          DisputeStatus.resolved,
          now: now.add(const Duration(days: 5)),
        );
        fail('expected StateError');
      } on StateError {
        expect(opened.status, DisputeStatus.submitted);
        expect(opened.updatedAt, now);
      }
    });
  });

  group('deterministic identifiers', () {
    test('the same inputs yield the same id', () {
      final DisputeTicket first = openFor(DisputeReason.duplicateCharge);
      final DisputeTicket second = openFor(DisputeReason.duplicateCharge);
      expect(first.id, second.id);
      expect(first.id.startsWith('DSP-'), isTrue);
    });

    test('a different reason yields a different id', () {
      final DisputeTicket a = openFor(DisputeReason.duplicateCharge);
      final DisputeTicket b = openFor(DisputeReason.incorrectAmount);
      expect(a.id, isNot(b.id));
    });
  });

  group('model helpers', () {
    test('copyWith preserves unspecified fields', () {
      final DisputeTicket opened = openFor(DisputeReason.duplicateCharge);
      final DisputeTicket updated =
          opened.copyWith(status: DisputeStatus.underReview);
      expect(updated.status, DisputeStatus.underReview);
      expect(updated.id, opened.id);
      expect(updated.transactionId, opened.transactionId);
      expect(updated.reason, opened.reason);
    });

    test('equality and hashCode follow field values', () {
      final DisputeTicket a = openFor(DisputeReason.duplicateCharge);
      final DisputeTicket b = openFor(DisputeReason.duplicateCharge);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(openFor(DisputeReason.incorrectAmount)));
    });

    test('eligibility equality and hashCode follow field values', () {
      const DisputeEligibility a = DisputeEligibility(
        isEligible: true,
        isExpired: false,
        daysSinceTransaction: 10,
        shouldSuggestCardFreeze: false,
      );
      const DisputeEligibility b = DisputeEligibility(
        isEligible: true,
        isExpired: false,
        daysSinceTransaction: 10,
        shouldSuggestCardFreeze: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString is informative and contains no markup', () {
      final DisputeTicket ticket = openFor(DisputeReason.unrecognizedTransaction);
      final String text = ticket.toString();
      expect(text.contains(ticket.id), isTrue);
      expect(text.contains('unrecognizedTransaction'), isTrue);
    });
  });
}
