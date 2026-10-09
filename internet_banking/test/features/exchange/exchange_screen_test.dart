import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/exchange/screens/exchange_screen.dart';
import 'package:internet_banking/widgets/success_badge.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// The exchange screen: sell on top, buy below, the bank's quote before anything moves.
void main() {
  setUpAll(setUpTestApp);

  Future<FakeApi> open(WidgetTester tester) async {
    usePhoneViewport(tester, size: const Size(400, 1000));
    final api = demoCustomerApi()
      ..routes['GET /currency/api/v1/exchange-rates'] = {
        'base': 'RON',
        'rates': {'RON': 1.0, 'EUR': 0.2, 'USD': 0.22, 'GBP': 0.17},
        'commission_percent': 0,
      }
      ..routes['POST /currency/api/v1/users/1/exchange/quote'] = {
        'quoteId': 'fxq-7',
        'sourceAmount': 100.0,
        'destinationAmount': 20.0,
        'rate': 0.2,
      }
      ..routes['POST /currency/api/v1/users/1/exchange/internal'] = {'success': true};
    api.install();
    await tester.pumpWidget(testApp(const ExchangeScreen(userId: 1)));
    await settle(tester);
    return api;
  }

  TextField field(WidgetTester tester, int index) => tester.widgetList<TextField>(find.byType(TextField)).elementAt(index);

  testWidgets('the bought amount follows the typed one at once and cannot be edited', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    expect(field(tester, 1).controller!.text, '20,00');
    expect(field(tester, 1).readOnly, isTrue);
    expect(find.text('Sold: 12.345,67 RON'), findsOneWidget);
    expect(find.text('Sold: 840,50 EUR'), findsOneWidget);
    expect(find.text('Fără comision'), findsOneWidget);
  });

  testWidgets('"All" sells the whole balance', (tester) async {
    await open(tester);

    await tester.tap(find.text('Tot soldul'));
    await tester.pump();

    expect(field(tester, 0).controller!.text, '12.345,67');
  });

  testWidgets('choosing the currency of the other side swaps them instead of matching', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('sell-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro'));
    await tester.pumpAndSettle();

    expect(find.text('1 EUR = 5,0000 RON'), findsOneWidget);
  });

  testWidgets('a currency without an account offers to open one', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('buy-currency')));
    await tester.pumpAndSettle();
    expect(find.text('Nu ai cont în GBP'), findsOneWidget);
    await tester.tap(find.text('Liră sterlină'));
    await tester.pumpAndSettle();

    expect(find.text('Deschide cont'), findsOneWidget);
  });

  testWidgets('after confirming, a success sheet shows what was exchanged', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();
    await tester.tap(find.text('Schimbă valuta'));
    await settle(tester);
    await tester.tap(find.text('Confirmă'));
    await settle(tester);

    expect(find.byType(SuccessBadge), findsOneWidget);
    expect(find.text('Schimb realizat'), findsOneWidget);
    expect(find.text('100,00 RON  →  20,00 EUR'), findsOneWidget);
    expect(field(tester, 0).controller!.text, isEmpty, reason: 'ready for the next exchange');
  });
}
