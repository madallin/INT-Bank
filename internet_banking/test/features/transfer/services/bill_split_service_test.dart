import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/services/bill_split_service.dart';

SplitParticipant participant(
  String id, {
  String? name,
  double? customAmount,
  double? percentage,
  bool paidBy = false,
}) {
  return SplitParticipant(
    id: id,
    name: name ?? id,
    customAmount: customAmount,
    percentage: percentage,
    paidBy: paidBy,
  );
}

void main() {
  final fixedNow = DateTime(2026, 5, 1, 12, 30, 45);
  BillSplitService buildService() =>
      BillSplitService(now: () => fixedNow);

  group('splitEqually', () {
    test('splits 100.00 among three as 33.34/33.33/33.33', () {
      final service = buildService();
      final calc = service.splitEqually(
        100.00,
        <SplitParticipant>[
          participant('a'),
          participant('b'),
          participant('c'),
        ],
      );

      expect(calc.method, SplitMethod.equally);
      expect(calc.currency, 'RON');
      expect(calc.totalAmount, 100.00);
      expect(calc.shares.length, 3);
      expect(calc.shares[0].cents, 3334);
      expect(calc.shares[1].cents, 3333);
      expect(calc.shares[2].cents, 3333);
      expect(calc.shares[0].amount, closeTo(33.34, 0.0001));
      expect(calc.shares[1].amount, closeTo(33.33, 0.0001));
      expect(calc.shares[2].amount, closeTo(33.33, 0.0001));
      expect(calc.sumOfSharesCents, 10000);
      expect(calc.sumOfShares, closeTo(100.00, 0.0001));
    });

    test('splits 100.00 among seven to the cent', () {
      final service = buildService();
      final calc = service.splitEqually(
        100.00,
        List<SplitParticipant>.generate(
          7,
          (int i) => participant('p$i'),
        ),
      );

      final List<int> cents =
          calc.shares.map((SplitShare s) => s.cents).toList();
      expect(cents, <int>[1429, 1429, 1429, 1429, 1428, 1428, 1428]);
      expect(calc.sumOfSharesCents, 10000);
    });

    test('gives the whole amount to a single participant', () {
      final service = buildService();
      final calc = service.splitEqually(
        42.42,
        <SplitParticipant>[participant('solo')],
      );

      expect(calc.shares.length, 1);
      expect(calc.shares.single.cents, 4242);
      expect(calc.sumOfSharesCents, 4242);
    });

    test('assigns a zero share when total is smaller than participants', () {
      final service = buildService();
      final calc = service.splitEqually(
        0.01,
        <SplitParticipant>[participant('a'), participant('b')],
      );

      expect(calc.shares[0].cents, 1);
      expect(calc.shares[1].cents, 0);
      expect(calc.sumOfSharesCents, 1);
    });

    test('preserves participant order and identity for paidBy', () {
      final service = buildService();
      final calc = service.splitEqually(
        30.00,
        <SplitParticipant>[
          participant('alice', paidBy: true),
          participant('bob'),
          participant('carol'),
        ],
      );

      expect(calc.shares[0].participantId, 'alice');
      expect(calc.shares[1].participantId, 'bob');
      expect(calc.shares[2].participantId, 'carol');
      expect(calc.shares[0].participantName, 'alice');
    });

    test('sum of cents equals total exactly across many cases', () {
      final service = buildService();
      const List<int> totalCentsCases = <int>[
        1, 2, 3, 7, 99, 100, 101, 999, 1000, 1001, 3333, 10000, 12345, 99999,
      ];

      for (final int totalCents in totalCentsCases) {
        for (int count = 1; count <= 12; count++) {
          final double total = totalCents / 100;
          final calc = service.splitEqually(
            total,
            List<SplitParticipant>.generate(
              count,
              (int i) => participant('p$i'),
            ),
          );
          expect(
            calc.sumOfSharesCents,
            totalCents,
            reason: 'equal total=$total count=$count',
          );
          expect(calc.sumOfShares, closeTo(total, 0.0001));
          for (final SplitShare share in calc.shares) {
            expect(share.cents, greaterThanOrEqualTo(0));
          }
        }
      }
    });

    test('supports a custom currency', () {
      final service = buildService();
      final calc = service.splitEqually(
        10.00,
        <SplitParticipant>[participant('a'), participant('b')],
        currency: 'EUR',
      );

      expect(calc.currency, 'EUR');
    });
  });

  group('splitCustomAmounts', () {
    test('accepts amounts that sum exactly to the total', () {
      final service = buildService();
      final calc = service.splitCustomAmounts(
        100.00,
        <SplitParticipant>[
          participant('a', customAmount: 40.00),
          participant('b', customAmount: 35.50),
          participant('c', customAmount: 24.50),
        ],
      );

      expect(calc.method, SplitMethod.customAmounts);
      expect(calc.shares.map((SplitShare s) => s.cents).toList(),
          <int>[4000, 3550, 2450]);
      expect(calc.sumOfSharesCents, 10000);
    });

    test('throws when the amounts do not sum to the total', () {
      final service = buildService();
      expect(
        () => service.splitCustomAmounts(
          100.00,
          <SplitParticipant>[
            participant('a', customAmount: 40.00),
            participant('b', customAmount: 35.50),
            participant('c', customAmount: 24.40),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message.toString(),
            'message',
            allOf(contains('expected'), contains('got')),
          ),
        ),
      );
    });

    test('throws for a zero custom amount', () {
      final service = buildService();
      expect(
        () => service.splitCustomAmounts(
          10.00,
          <SplitParticipant>[
            participant('a', customAmount: 10.00),
            participant('b', customAmount: 0.00),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a negative custom amount', () {
      final service = buildService();
      expect(
        () => service.splitCustomAmounts(
          10.00,
          <SplitParticipant>[
            participant('a', customAmount: 12.00),
            participant('b', customAmount: -2.00),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a missing custom amount', () {
      final service = buildService();
      expect(
        () => service.splitCustomAmounts(
          10.00,
          <SplitParticipant>[
            participant('a', customAmount: 5.00),
            participant('b'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('splitByPercentages', () {
    test('allocates cents by largest remainder', () {
      final service = buildService();
      final calc = service.splitByPercentages(
        100.00,
        <SplitParticipant>[
          participant('a', percentage: 33.333),
          participant('b', percentage: 33.333),
          participant('c', percentage: 33.334),
        ],
      );

      expect(calc.method, SplitMethod.percentages);
      expect(calc.shares.map((SplitShare s) => s.cents).toList(),
          <int>[3333, 3333, 3334]);
      expect(calc.sumOfSharesCents, 10000);
    });

    test('resolves rounding ties by participant order', () {
      final service = buildService();
      final calc = service.splitByPercentages(
        0.01,
        <SplitParticipant>[
          participant('a', percentage: 50.0),
          participant('b', percentage: 50.0),
        ],
      );

      expect(calc.shares[0].cents, 1);
      expect(calc.shares[1].cents, 0);
      expect(calc.sumOfSharesCents, 1);
    });

    test('allocates a small total without exceeding it', () {
      final service = buildService();
      final calc = service.splitByPercentages(
        0.10,
        <SplitParticipant>[
          participant('a', percentage: 33.333),
          participant('b', percentage: 33.333),
          participant('c', percentage: 33.334),
        ],
      );

      expect(calc.shares.map((SplitShare s) => s.cents).toList(),
          <int>[3, 3, 4]);
      expect(calc.sumOfSharesCents, 10);
    });

    test('throws when percentages do not sum to 100', () {
      final service = buildService();
      expect(
        () => service.splitByPercentages(
          100.00,
          <SplitParticipant>[
            participant('a', percentage: 50.0),
            participant('b', percentage: 40.0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a zero percentage', () {
      final service = buildService();
      expect(
        () => service.splitByPercentages(
          100.00,
          <SplitParticipant>[
            participant('a', percentage: 100.0),
            participant('b', percentage: 0.0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a negative percentage', () {
      final service = buildService();
      expect(
        () => service.splitByPercentages(
          100.00,
          <SplitParticipant>[
            participant('a', percentage: 110.0),
            participant('b', percentage: -10.0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a missing percentage', () {
      final service = buildService();
      expect(
        () => service.splitByPercentages(
          100.00,
          <SplitParticipant>[
            participant('a', percentage: 50.0),
            participant('b', percentage: 50.0),
            participant('c'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('sum of cents equals total for equal percentage splits', () {
      final service = buildService();
      for (final int count in <int>[2, 3, 4, 5, 6, 7, 8, 10, 11]) {
        final double percentage = 100.0 / count;
        final calc = service.splitByPercentages(
          87.65,
          List<SplitParticipant>.generate(
            count,
            (int i) => participant('p$i', percentage: percentage),
          ),
        );
        expect(
          calc.sumOfSharesCents,
          8765,
          reason: 'count=$count',
        );
      }
    });
  });

  group('validation', () {
    test('throws for an empty participant list', () {
      final service = buildService();
      expect(
        () => service.splitEqually(10.00, <SplitParticipant>[]),
        throwsArgumentError,
      );
    });

    test('throws for duplicate participant ids', () {
      final service = buildService();
      expect(
        () => service.splitEqually(
          10.00,
          <SplitParticipant>[participant('dup'), participant('dup')],
        ),
        throwsArgumentError,
      );
    });

    test('throws for an empty participant id', () {
      final service = buildService();
      expect(
        () => service.splitEqually(
          10.00,
          <SplitParticipant>[participant('')],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a zero total', () {
      final service = buildService();
      expect(
        () => service.splitEqually(
          0.00,
          <SplitParticipant>[participant('a')],
        ),
        throwsArgumentError,
      );
    });

    test('throws for a negative total', () {
      final service = buildService();
      expect(
        () => service.splitEqually(
          -5.00,
          <SplitParticipant>[participant('a')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('generatePaymentRequests', () {
    test('creates one request per debtor excluding the payer', () {
      final service = buildService();
      final calc = service.splitEqually(
        100.00,
        <SplitParticipant>[
          participant('alice', name: 'Alice'),
          participant('bob', name: 'Bob'),
          participant('carol', name: 'Carol'),
        ],
      );

      final List<PaymentRequestData> requests =
          service.generatePaymentRequests(calc, payerId: 'alice');

      expect(requests.length, 2);
      expect(requests[0].payerId, 'alice');
      expect(requests[0].debtorId, 'bob');
      expect(requests[0].debtorName, 'Bob');
      expect(requests[0].amount, closeTo(33.33, 0.0001));
      expect(requests[1].debtorId, 'carol');
      expect(requests[1].amount, closeTo(33.33, 0.0001));
      expect(requests[0].currency, 'RON');
      expect(requests[0].createdAt, fixedNow);
    });

    test('amounts match the corresponding shares exactly', () {
      final service = buildService();
      final calc = service.splitEqually(
        100.00,
        List<SplitParticipant>.generate(
          3,
          (int i) => participant('p$i'),
        ),
      );

      final List<PaymentRequestData> requests =
          service.generatePaymentRequests(calc, payerId: 'nobody');

      expect(requests.length, 3);
      for (int i = 0; i < requests.length; i++) {
        expect(requests[i].amount, calc.shares[i].amount);
        expect(requests[i].amount, closeTo(calc.shares[i].cents / 100, 0.0));
        expect(requests[i].debtorId, calc.shares[i].participantId);
      }
    });

    test('produces deterministic lower-case hexadecimal ids', () {
      final service = buildService();
      final calc = service.splitEqually(
        100.00,
        <SplitParticipant>[
          participant('a'),
          participant('b'),
          participant('c'),
        ],
      );

      final List<PaymentRequestData> first =
          service.generatePaymentRequests(calc, payerId: 'a');
      final List<PaymentRequestData> second =
          buildService().generatePaymentRequests(calc, payerId: 'a');

      final RegExp hex = RegExp(r'^[0-9a-f]{8}$');
      for (int i = 0; i < first.length; i++) {
        expect(first[i].requestId, second[i].requestId);
        expect(hex.hasMatch(first[i].requestId), isTrue);
      }
      expect(first[0].requestId, isNot(first[1].requestId));
    });

    test('ids differ for different payers', () {
      final service = buildService();
      final calc = service.splitEqually(
        50.00,
        <SplitParticipant>[participant('a'), participant('b')],
      );

      final List<PaymentRequestData> asA =
          service.generatePaymentRequests(calc, payerId: 'a');
      final List<PaymentRequestData> asB =
          service.generatePaymentRequests(calc, payerId: 'b');

      expect(asA.single.debtorId, 'b');
      expect(asB.single.debtorId, 'a');
      expect(asA.single.requestId, isNot(asB.single.requestId));
    });

    test('applies the note and injected clock', () {
      final service = buildService();
      final calc = service.splitEqually(
        20.00,
        <SplitParticipant>[participant('a'), participant('b')],
      );

      final List<PaymentRequestData> requests = service.generatePaymentRequests(
        calc,
        payerId: 'a',
        note: 'Dinner',
      );

      expect(requests.single.note, 'Dinner');
      expect(requests.single.createdAt, fixedNow);
    });

    test('uses the calculation currency', () {
      final service = buildService();
      final calc = service.splitEqually(
        20.00,
        <SplitParticipant>[participant('a'), participant('b')],
        currency: 'EUR',
      );

      final List<PaymentRequestData> requests =
          service.generatePaymentRequests(calc, payerId: 'a');

      expect(requests.single.currency, 'EUR');
    });

    test('throws for an empty payer id', () {
      final service = buildService();
      final calc = service.splitEqually(
        20.00,
        <SplitParticipant>[participant('a'), participant('b')],
      );

      expect(
        () => service.generatePaymentRequests(calc, payerId: ''),
        throwsArgumentError,
      );
    });
  });

  group('model behaviour', () {
    test('SplitParticipant copyWith and equality', () {
      const SplitParticipant original = SplitParticipant(
        id: 'a',
        name: 'Alice',
        percentage: 50.0,
      );
      final SplitParticipant copy = original.copyWith(name: 'Alicia');

      expect(copy.name, 'Alicia');
      expect(copy.id, 'a');
      expect(copy.percentage, 50.0);
      expect(copy, isNot(original));
      expect(original, original.copyWith());
      expect(original.hashCode, original.copyWith().hashCode);
    });

    test('BillSplitCalculation exposes exact sums', () {
      final service = buildService();
      final calc = service.splitEqually(
        10.00,
        List<SplitParticipant>.generate(
          3,
          (int i) => participant('p$i'),
        ),
      );

      expect(calc.totalCents, 1000);
      expect(calc.sumOfSharesCents, 1000);
      expect(calc.sumOfShares, closeTo(10.00, 0.0001));
      expect(calc, calc);
    });
  });
}
