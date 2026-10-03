import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/data/models/transaction_entry.dart';

void main() {
  group('TransactionEntry.fromJson', () {
    test('reads the current API contract', () {
      final debit = TransactionEntry.fromJson({
        'id': 7,
        'amount': 150.5,
        'currency': 'EUR',
        'type': 'DEBIT',
        'reason': 'Chirie',
        'date': '2026-09-30T10:15:00',
        'fromIban': 'RO49INTB0001EUR0001',
        'toIban': 'RO12BTRL0000000001',
      });
      expect(debit.amount, 150.5);
      expect(debit.isIncoming, isFalse);
      expect(debit.signedAmount, -150.5);
      expect(debit.currency, 'EUR');
      expect(debit.title, 'Chirie');
      expect(debit.date, DateTime(2026, 9, 30, 10, 15));
      expect(debit.searchText, contains('btrl'));

      final credit = TransactionEntry.fromJson({'amount': '20', 'type': 'CREDIT'});
      expect(credit.isIncoming, isTrue);
      expect(credit.signedAmount, 20);
    });

    test('accepts the legacy Romanian keys', () {
      final entry = TransactionEntry.fromJson({
        'suma': 42,
        'moneda': 'RON',
        'type': 'received',
        'motiv': 'Rambursare',
        'dataTransfer': '2026-01-02',
      });
      expect(entry.amount, 42);
      expect(entry.isIncoming, isTrue);
      expect(entry.currency, 'RON');
      expect(entry.title, 'Rambursare');
      expect(entry.date, DateTime(2026, 1, 2));
    });

    test('never throws on missing fields', () {
      final entry = TransactionEntry.fromJson({});
      expect(entry.amount, 0);
      expect(entry.title, 'Transfer bancar');
      expect(entry.date, isNull);
      expect(entry.currency, isNull);
    });
  });
}
