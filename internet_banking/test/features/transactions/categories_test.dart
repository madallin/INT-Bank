import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/data/models/transaction_category.dart';
import 'package:internet_banking/data/models/transaction_entry.dart';
import 'package:internet_banking/features/analytics/screens/spending_analytics_screen.dart';
import 'package:internet_banking/features/transactions/screens/transaction_history_screen.dart';
import 'package:internet_banking/features/transactions/widgets/transaction_details_bottom_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// What each transaction was for: the bank's category drives its icon, colour and name.
void main() {
  setUpAll(setUpTestApp);

  test('reads the category the bank sends, and copes without one', () {
    expect(TransactionEntry.fromJson({'amount': 5, 'type': 'DEBIT', 'category': 'UTILITATI'}).category, TransactionCategory.bills);
    expect(TransactionEntry.fromJson({'amount': 5, 'type': 'CREDIT', 'category': 'INCOMING'}).category, TransactionCategory.incoming);
    expect(TransactionEntry.fromJson({'amount': 5, 'type': 'DEBIT'}).category, isNull, reason: 'older server');
    expect(TransactionEntry.fromJson({'amount': 5, 'type': 'DEBIT', 'category': 'SOMETHING_NEW'}).category, isNull);
  });

  testWidgets('history shows each payment with its category icon', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1200));
    demoCustomerApi()
      ..routes['GET /users/1/accounts/101/transactions'] = {
        'transactions': [
          {'id': 1, 'amount': 80, 'type': 'DEBIT', 'reason': 'Factură Enel', 'date': '2026-10-04T10:00:00', 'category': 'UTILITATI'},
          {'id': 2, 'amount': 30, 'type': 'DEBIT', 'reason': 'Pizza', 'date': '2026-10-03T10:00:00', 'category': 'RESTAURANTE'},
          {'id': 3, 'amount': 900, 'type': 'CREDIT', 'reason': 'Salariu', 'date': '2026-10-02T10:00:00', 'category': 'INCOMING'},
          {'id': 4, 'amount': 50, 'type': 'DEBIT', 'reason': 'Economii', 'date': '2026-10-01T10:00:00', 'category': 'OWN_ACCOUNTS'},
          {'id': 5, 'amount': 10, 'type': 'DEBIT', 'reason': 'Datorie', 'date': '2026-09-30T10:00:00'},
        ],
      }
      ..install();

    await tester.pumpWidget(testApp(const TransactionHistoryScreen(userId: 1, accountId: 101)));
    await settle(tester);

    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget, reason: 'no category: money-out arrow');
  });

  testWidgets('the details sheet names the category', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1000));
    await tester.pumpWidget(testApp(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => TransactionDetailsBottomSheet.show(context, {
            'id': 1, 'amount': 80, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Factură Enel',
            'date': '2026-10-04T10:00:00', 'status': 'PENDING', 'category': 'UTILITATI',
          }),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Categorie'), findsOneWidget);
    expect(find.text('Facturi și utilități'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget, reason: 'a pending payment is not shown as done');
  });

  testWidgets('insights name categories in the app language, not the server language', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1400));
    demoCustomerApi()
      ..routes['GET /users/1/accounts/101/analytics'] = {
        'currency': 'RON',
        'totalSpent': 300.0,
        'topCategory': 'Alimente & Supermarket',
        'totalTransactions': 3,
        'categories': [
          {'categoryKey': 'ALIMENTE', 'categoryName': 'Alimente & Supermarket', 'amount': 200.0, 'percentage': 66.7, 'transactionCount': 2},
          {'categoryKey': 'TRANSPORT', 'categoryName': 'Transport & Combustibil', 'amount': 100.0, 'percentage': 33.3, 'transactionCount': 1},
        ],
      }
      ..install();

    await tester.pumpWidget(testApp(
      const SpendingAnalyticsScreen(userId: 1, accountId: 101, currency: 'RON'),
      locale: const Locale('en'),
    ));
    await settle(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Transport & fuel'), findsOneWidget);
    expect(find.textContaining('Groceries'), findsNWidgets(2), reason: 'the top category too');
    expect(find.textContaining('Supermarket'), findsNothing);
  });
}
