import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transactions/screens/transaction_history_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

String _stamp(DateTime d) => d.toIso8601String().split('.').first;

void main() {
  setUpAll(setUpTestApp);

  testWidgets('history is grouped under Today, Yesterday and dated headings', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1400));
    final now = DateTime.now();
    final older = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 9));
    demoCustomerApi()
      ..routes['GET /users/1/accounts/101/transactions'] = {
        'transactions': [
          {'id': 1, 'amount': 20, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Cafea', 'date': _stamp(now), 'status': 'COMPLETED'},
          {'id': 2, 'amount': 30, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Taxi', 'date': _stamp(now), 'status': 'COMPLETED'},
          {'id': 3, 'amount': 90, 'currency': 'RON', 'type': 'CREDIT', 'reason': 'Rambursare', 'date': _stamp(now.subtract(const Duration(days: 1))), 'status': 'COMPLETED'},
          {'id': 4, 'amount': 50, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Chirie', 'date': _stamp(older), 'status': 'COMPLETED'},
        ],
      }
      ..install();

    await tester.pumpWidget(testApp(const TransactionHistoryScreen(userId: 1, accountId: 101)));
    await settle(tester);

    expect(find.text('Astăzi'), findsOneWidget, reason: 'one heading for both of today\'s payments');
    expect(find.text('Ieri'), findsOneWidget);
    final olderLabel = '${older.day.toString().padLeft(2, '0')}.${older.month.toString().padLeft(2, '0')}.${older.year}';
    expect(find.text(olderLabel), findsOneWidget);

    // Headings sit above their own transactions.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Astăzi'), lessThan(top('Cafea')));
    expect(top('Taxi'), lessThan(top('Ieri')));
    expect(top('Ieri'), lessThan(top('Rambursare')));
    expect(top('Rambursare'), lessThan(top(olderLabel)));
    expect(top(olderLabel), lessThan(top('Chirie')));

    // Each day shows its net movement next to the heading.
    expect(find.text('-50,00'), findsWidgets, reason: "today's two payments");
    expect(find.text('+90,00'), findsWidgets, reason: "yesterday's refund");
  });
}
