import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/services/standing_order_service.dart';

const String validIban = 'RO49AAAA1B31007593840000';
const String invalidChecksumIban = 'RO49AAAA1B31007593840001';

StandingOrder buildOrder({
  String id = 'so-1',
  String sourceAccountId = 'acc-1',
  String destinationIban = validIban,
  String beneficiaryName = 'Acme SRL',
  double amount = 100.0,
  String currency = 'RON',
  Frequency frequency = Frequency.monthly,
  DateTime? startDate,
  DateTime? nextExecutionDate,
  DateTime? endDate,
  StandingOrderStatus status = StandingOrderStatus.active,
  String? description,
}) {
  final DateTime start = startDate ?? DateTime(2026, 1, 15);
  return StandingOrder(
    id: id,
    sourceAccountId: sourceAccountId,
    destinationIban: destinationIban,
    beneficiaryName: beneficiaryName,
    amount: amount,
    currency: currency,
    frequency: frequency,
    startDate: start,
    nextExecutionDate: nextExecutionDate ?? start,
    endDate: endDate,
    status: status,
    description: description,
  );
}

void main() {
  final service = StandingOrderService();

  group('calculateNextExecutionDate weekly and biWeekly', () {
    test('weekly adds seven days', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 3, 10),
          Frequency.weekly,
        ),
        DateTime(2026, 3, 17),
      );
    });

    test('weekly crosses a month boundary', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 1, 28),
          Frequency.weekly,
        ),
        DateTime(2023, 2, 4),
      );
    });

    test('weekly crosses a year boundary', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 12, 29),
          Frequency.weekly,
        ),
        DateTime(2024, 1, 5),
      );
    });

    test('biWeekly adds fourteen days', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 3, 10),
          Frequency.biWeekly,
        ),
        DateTime(2026, 3, 24),
      );
    });

    test('biWeekly crosses a year boundary', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 12, 25),
          Frequency.biWeekly,
        ),
        DateTime(2024, 1, 8),
      );
    });
  });

  group('calculateNextExecutionDate monthly', () {
    test('keeps the day for a regular month', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 1, 15),
          Frequency.monthly,
        ),
        DateTime(2026, 2, 15),
      );
    });

    test('crosses a year boundary', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 12, 15),
          Frequency.monthly,
        ),
        DateTime(2027, 1, 15),
      );
    });

    test('clamps the 31st to February in a non-leap year', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 1, 31),
          Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2023, 2, 28),
      );
    });

    test('clamps the 31st to February in a leap year', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2024, 1, 31),
          Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2024, 2, 29),
      );
    });

    test('restores the 31st after a clamped February', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 2, 28),
          Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2023, 3, 31),
      );
    });

    test('full 31 Jan to 28 Feb to 31 Mar sequence', () {
      DateTime next = service.calculateNextExecutionDate(
        DateTime(2023, 1, 31),
        Frequency.monthly,
        anchorDay: 31,
      );
      expect(next, DateTime(2023, 2, 28));

      next = service.calculateNextExecutionDate(
        next,
        Frequency.monthly,
        anchorDay: 31,
      );
      expect(next, DateTime(2023, 3, 31));
    });

    test('clamps the 30th in February and restores it in March', () {
      DateTime next = service.calculateNextExecutionDate(
        DateTime(2023, 1, 30),
        Frequency.monthly,
        anchorDay: 30,
      );
      expect(next, DateTime(2023, 2, 28));

      next = service.calculateNextExecutionDate(
        next,
        Frequency.monthly,
        anchorDay: 30,
      );
      expect(next, DateTime(2023, 3, 30));
    });

    test('clamps the 31st to 30 days in April', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 3, 31),
          Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2023, 4, 30),
      );
    });

    test('uses the current day as the default anchor', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 1, 31),
          Frequency.monthly,
        ),
        DateTime(2023, 2, 28),
      );
    });
  });

  group('calculateNextExecutionDate quarterly and annually', () {
    test('quarterly adds three months', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 1, 15),
          Frequency.quarterly,
        ),
        DateTime(2026, 4, 15),
      );
    });

    test('quarterly clamps to February in a leap year', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 11, 30),
          Frequency.quarterly,
          anchorDay: 30,
        ),
        DateTime(2024, 2, 29),
      );
    });

    test('quarterly restores the 31st after a clamped month', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 2, 28),
          Frequency.quarterly,
          anchorDay: 31,
        ),
        DateTime(2023, 5, 31),
      );
    });

    test('annually adds twelve months', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2026, 1, 15),
          Frequency.annually,
        ),
        DateTime(2027, 1, 15),
      );
    });

    test('annually clamps a 29 Feb anchor to 28 Feb in a non-leap year', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2024, 2, 29),
          Frequency.annually,
          anchorDay: 29,
        ),
        DateTime(2025, 2, 28),
      );
    });

    test('annually keeps the 31st when the next year has the day', () {
      expect(
        service.calculateNextExecutionDate(
          DateTime(2023, 1, 31),
          Frequency.annually,
          anchorDay: 31,
        ),
        DateTime(2024, 1, 31),
      );
    });

    test('preserves time of day when advancing', () {
      final DateTime result = service.calculateNextExecutionDate(
        DateTime(2026, 1, 31, 9, 30, 15),
        Frequency.monthly,
        anchorDay: 31,
      );
      expect(result, DateTime(2026, 2, 28, 9, 30, 15));
    });

    test('preserves the UTC flag when advancing', () {
      final DateTime result = service.calculateNextExecutionDate(
        DateTime.utc(2026, 1, 31),
        Frequency.monthly,
        anchorDay: 31,
      );
      expect(result.isUtc, isTrue);
      expect(result, DateTime.utc(2026, 2, 28));
    });

    test('throws when the anchor day is out of range', () {
      expect(
        () => service.calculateNextExecutionDate(
          DateTime(2026, 1, 1),
          Frequency.monthly,
          anchorDay: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateNextExecutionDate(
          DateTime(2026, 1, 1),
          Frequency.monthly,
          anchorDay: 32,
        ),
        throwsArgumentError,
      );
    });
  });

  group('projectedAnnualExecutionCount', () {
    test('returns the documented count for every frequency', () {
      expect(service.projectedAnnualExecutionCount(Frequency.weekly), 52);
      expect(service.projectedAnnualExecutionCount(Frequency.biWeekly), 26);
      expect(service.projectedAnnualExecutionCount(Frequency.monthly), 12);
      expect(service.projectedAnnualExecutionCount(Frequency.quarterly), 4);
      expect(service.projectedAnnualExecutionCount(Frequency.annually), 1);
    });
  });

  group('projectedAnnualExecutionSum', () {
    test('multiplies and rounds monthly amounts to cents', () {
      final order = buildOrder(amount: 100.555, frequency: Frequency.monthly);
      expect(service.projectedAnnualExecutionSum(order), closeTo(1206.66, 0.001));
    });

    test('computes weekly totals', () {
      final order = buildOrder(amount: 10.0, frequency: Frequency.weekly);
      expect(service.projectedAnnualExecutionSum(order), closeTo(520.0, 0.001));
    });

    test('computes biWeekly totals', () {
      final order = buildOrder(amount: 10.0, frequency: Frequency.biWeekly);
      expect(service.projectedAnnualExecutionSum(order), closeTo(260.0, 0.001));
    });

    test('computes quarterly totals', () {
      final order = buildOrder(amount: 33.335, frequency: Frequency.quarterly);
      expect(service.projectedAnnualExecutionSum(order), closeTo(133.34, 0.001));
    });

    test('computes annually totals with rounding', () {
      final order = buildOrder(amount: 99.999, frequency: Frequency.annually);
      expect(service.projectedAnnualExecutionSum(order), closeTo(100.0, 0.001));
    });
  });

  group('isValidRoIban', () {
    test('accepts a valid RO IBAN', () {
      expect(service.isValidRoIban(validIban), isTrue);
    });

    test('accepts a lowercase RO IBAN with spaces', () {
      expect(
        service.isValidRoIban('ro49 aaaa 1b31 0075 9384 0000'),
        isTrue,
      );
    });

    test('rejects a wrong checksum', () {
      expect(service.isValidRoIban(invalidChecksumIban), isFalse);
    });

    test('rejects a non-RO IBAN', () {
      expect(service.isValidRoIban('DE89370400440532013000'), isFalse);
    });

    test('rejects an IBAN of the wrong length', () {
      expect(service.isValidRoIban('RO49AAAA1B3100759384000'), isFalse);
      expect(service.isValidRoIban('RO49AAAA1B310075938400000'), isFalse);
    });

    test('rejects illegal characters', () {
      expect(service.isValidRoIban('RO49AAAA1B3100759384@000'), isFalse);
    });
  });

  group('create', () {
    test('creates an active order with nextExecutionDate equal to startDate', () {
      final order = service.create(
        id: 'so-9',
        sourceAccountId: 'acc-9',
        destinationIban: validIban,
        beneficiaryName: 'Acme SRL',
        amount: 250.0,
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 20),
      );
      expect(order.status, StandingOrderStatus.active);
      expect(order.nextExecutionDate, DateTime(2026, 5, 20));
      expect(order.startDate, DateTime(2026, 5, 20));
      expect(order.currency, 'RON');
      expect(order.amount, closeTo(250.0, 0.001));
      expect(order.endDate, isNull);
      expect(order.description, isNull);
    });

    test('rounds the amount to cents', () {
      final order = service.create(
        id: 'so-9',
        sourceAccountId: 'acc-9',
        destinationIban: validIban,
        beneficiaryName: 'Acme SRL',
        amount: 12.345,
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 20),
      );
      expect(order.amount, closeTo(12.35, 0.001));
    });

    test('normalizes the IBAN casing and spacing', () {
      final order = service.create(
        id: 'so-9',
        sourceAccountId: 'acc-9',
        destinationIban: 'ro49 aaaa 1b31 0075 9384 0000',
        beneficiaryName: 'Acme SRL',
        amount: 10.0,
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 20),
      );
      expect(order.destinationIban, validIban);
    });

    test('stores optional fields', () {
      final order = service.create(
        id: 'so-9',
        sourceAccountId: 'acc-9',
        destinationIban: validIban,
        beneficiaryName: 'Acme SRL',
        amount: 10.0,
        currency: 'EUR',
        frequency: Frequency.weekly,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2027, 5, 20),
        description: 'Rent',
      );
      expect(order.currency, 'EUR');
      expect(order.endDate, DateTime(2027, 5, 20));
      expect(order.description, 'Rent');
    });

    test('rejects a zero or negative amount', () {
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: 0.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: -1.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-finite amount', () {
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: double.nan,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: double.infinity,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an invalid IBAN', () {
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: invalidChecksumIban,
          beneficiaryName: 'Acme SRL',
          amount: 10.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty required identifiers', () {
      expect(
        () => service.create(
          id: '  ',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: 10.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: '',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: 10.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: '',
          amount: 10.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: 10.0,
          currency: '',
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an endDate before startDate', () {
      expect(
        () => service.create(
          id: 'so-9',
          sourceAccountId: 'acc-9',
          destinationIban: validIban,
          beneficiaryName: 'Acme SRL',
          amount: 10.0,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 20),
          endDate: DateTime(2026, 5, 19),
        ),
        throwsArgumentError,
      );
    });

    test('accepts an endDate equal to startDate', () {
      final order = service.create(
        id: 'so-9',
        sourceAccountId: 'acc-9',
        destinationIban: validIban,
        beneficiaryName: 'Acme SRL',
        amount: 10.0,
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 20),
      );
      expect(order.endDate, DateTime(2026, 5, 20));
    });
  });

  group('pause', () {
    test('moves an active order to paused and preserves other fields', () {
      final order = buildOrder();
      final StandingOrder paused = service.pause(order);
      expect(paused.status, StandingOrderStatus.paused);
      expect(paused.id, order.id);
      expect(paused.nextExecutionDate, order.nextExecutionDate);
      expect(order.status, StandingOrderStatus.active);
    });

    test('throws when pausing a paused order', () {
      expect(
        () => service.pause(buildOrder(status: StandingOrderStatus.paused)),
        throwsStateError,
      );
    });

    test('throws when pausing a cancelled order', () {
      expect(
        () => service.pause(buildOrder(status: StandingOrderStatus.cancelled)),
        throwsStateError,
      );
    });

    test('throws when pausing a completed order', () {
      expect(
        () => service.pause(buildOrder(status: StandingOrderStatus.completed)),
        throwsStateError,
      );
    });
  });

  group('resume', () {
    test('moves a paused order to active', () {
      final order = buildOrder(
        status: StandingOrderStatus.paused,
        nextExecutionDate: DateTime(2026, 3, 15),
      );
      final StandingOrder resumed =
          service.resume(order, from: DateTime(2026, 3, 1));
      expect(resumed.status, StandingOrderStatus.active);
      expect(resumed.nextExecutionDate, DateTime(2026, 3, 15));
    });

    test('skips missed executions and never schedules in the past', () {
      final order = buildOrder(
        status: StandingOrderStatus.paused,
        startDate: DateTime(2026, 1, 15),
        nextExecutionDate: DateTime(2026, 1, 15),
      );
      final DateTime from = DateTime(2026, 4, 20);
      final StandingOrder resumed = service.resume(order, from: from);
      expect(resumed.status, StandingOrderStatus.active);
      expect(resumed.nextExecutionDate, DateTime(2026, 5, 15));
      expect(resumed.nextExecutionDate.isBefore(from), isFalse);
    });

    test('schedules on the from date when it matches an execution', () {
      final order = buildOrder(
        status: StandingOrderStatus.paused,
        startDate: DateTime(2026, 1, 15),
        nextExecutionDate: DateTime(2026, 1, 15),
      );
      final StandingOrder resumed =
          service.resume(order, from: DateTime(2026, 3, 15));
      expect(resumed.nextExecutionDate, DateTime(2026, 3, 15));
    });

    test('uses the injected clock when from is omitted', () {
      final DateTime fixedNow = DateTime(2026, 4, 20);
      final clocked = StandingOrderService(now: () => fixedNow);
      final order = buildOrder(
        status: StandingOrderStatus.paused,
        startDate: DateTime(2026, 1, 15),
        nextExecutionDate: DateTime(2026, 1, 15),
      );
      final StandingOrder resumed = clocked.resume(order);
      expect(resumed.nextExecutionDate, DateTime(2026, 5, 15));
    });

    test('preserves the anchor day across clamping when resuming', () {
      final order = buildOrder(
        frequency: Frequency.monthly,
        status: StandingOrderStatus.paused,
        startDate: DateTime(2023, 1, 31),
        nextExecutionDate: DateTime(2023, 1, 31),
      );
      final StandingOrder resumed =
          service.resume(order, from: DateTime(2023, 3, 1));
      expect(resumed.nextExecutionDate, DateTime(2023, 3, 31));
    });

    test('throws when resuming an active order', () {
      expect(
        () => service.resume(buildOrder(), from: DateTime(2026, 6, 1)),
        throwsStateError,
      );
    });

    test('throws when resuming a cancelled order', () {
      expect(
        () => service.resume(
          buildOrder(status: StandingOrderStatus.cancelled),
          from: DateTime(2026, 6, 1),
        ),
        throwsStateError,
      );
    });
  });

  group('cancel', () {
    test('cancels an active order', () {
      final order = service.cancel(buildOrder());
      expect(order.status, StandingOrderStatus.cancelled);
    });

    test('cancels a paused order', () {
      final order =
          service.cancel(buildOrder(status: StandingOrderStatus.paused));
      expect(order.status, StandingOrderStatus.cancelled);
    });

    test('throws when cancelling a cancelled order', () {
      expect(
        () =>
            service.cancel(buildOrder(status: StandingOrderStatus.cancelled)),
        throwsStateError,
      );
    });

    test('throws when cancelling a completed order', () {
      expect(
        () =>
            service.cancel(buildOrder(status: StandingOrderStatus.completed)),
        throwsStateError,
      );
    });
  });

  group('complete', () {
    test('throws when the order has no endDate', () {
      expect(
        () => service.complete(buildOrder(), asOf: DateTime(2030, 1, 1)),
        throwsStateError,
      );
    });

    test('throws when the endDate has not been reached', () {
      final order = buildOrder(endDate: DateTime(2026, 12, 31));
      expect(
        () => service.complete(order, asOf: DateTime(2026, 12, 30)),
        throwsStateError,
      );
    });

    test('completes once the endDate is reached', () {
      final order = buildOrder(endDate: DateTime(2026, 12, 31));
      final completed = service.complete(order, asOf: DateTime(2026, 12, 31));
      expect(completed.status, StandingOrderStatus.completed);
    });

    test('completes after the endDate has passed', () {
      final order = buildOrder(endDate: DateTime(2026, 12, 31));
      final completed = service.complete(order, asOf: DateTime(2027, 1, 5));
      expect(completed.status, StandingOrderStatus.completed);
    });

    test('throws when completing an already completed order', () {
      final order = buildOrder(
        endDate: DateTime(2026, 12, 31),
        status: StandingOrderStatus.completed,
      );
      expect(
        () => service.complete(order, asOf: DateTime(2027, 1, 5)),
        throwsStateError,
      );
    });
  });

  group('model equality and copyWith', () {
    test('two orders with the same fields are equal', () {
      final a = buildOrder();
      final b = buildOrder();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith replaces selected fields and keeps the rest', () {
      final order = buildOrder(amount: 100.0);
      final updated = order.copyWith(
        amount: 200.0,
        status: StandingOrderStatus.paused,
      );
      expect(updated.amount, closeTo(200.0, 0.001));
      expect(updated.status, StandingOrderStatus.paused);
      expect(updated.id, order.id);
      expect(updated.nextExecutionDate, order.nextExecutionDate);
    });

    test('toString exposes the order id and status', () {
      final order = buildOrder();
      expect(order.toString(), contains('so-1'));
      expect(order.toString(), contains('active'));
    });
  });
}
