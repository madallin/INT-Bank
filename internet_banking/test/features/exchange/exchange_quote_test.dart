import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/exchange/screens/exchange_screen.dart';
import 'package:internet_banking/services/currency_service.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// The customer confirms the bank's quote, and the exchange executes that quote.
void main() {
  setUpAll(setUpTestApp);

  testWidgets('confirms the quoted amounts and executes the quote, not a new price', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    final api = demoCustomerApi()
      ..routes['GET /currency/api/v1/exchange-rates'] = {
        'base': 'RON',
        'rates': {'RON': 1.0, 'EUR': 0.2, 'USD': 0.22, 'GBP': 0.17},
        'commission_percent': 0,
      }
      ..routes['POST /currency/api/v1/users/1/exchange/quote'] = {
        'quoteId': 'fxq-42',
        'sourceAmount': 100.0,
        'sourceCurrency': 'RON',
        'destinationAmount': 20.1,
        'destinationCurrency': 'EUR',
        'rate': 0.201,
        'expiresAt': '2026-10-05T10:01:00Z',
      }
      ..routes['POST /currency/api/v1/users/1/exchange/internal'] = {'success': true, 'exchangeId': 'FX-1'};
    api.install();

    await tester.pumpWidget(testApp(const ExchangeScreen(userId: 1)));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '100');
    await settle(tester);
    await tester.ensureVisible(find.text('Schimbă valuta'));
    await tester.tap(find.text('Schimbă valuta'));
    await settle(tester);

    // The sheet shows the bank's numbers, not the app's estimate.
    expect(find.text('20,10 EUR'), findsOneWidget);
    expect(find.textContaining('garantate 60 de secunde'), findsOneWidget);
    expect(api.calls, isNot(contains('POST /currency/api/v1/users/1/exchange/internal')));

    await tester.tap(find.text('Confirmă'));
    await settle(tester);

    final i = api.calls.indexOf('POST /currency/api/v1/users/1/exchange/internal');
    expect(i, isNot(-1));
    expect(api.sentBodies[i], {'quoteId': 'fxq-42'});
  });

  test('reads the rates in the shape the server sends', () {
    final rates = CurrencyService.parseRates({
      'base': 'RON',
      'rates': {'RON': 1.0, 'EUR': 0.2, 'USD': 0.25},
    });
    expect(rates['RON']!['EUR'], 0.2);
    expect(rates['EUR']!['RON'], closeTo(5.0, 1e-9));
    expect(rates['EUR']!['USD'], closeTo(1.25, 1e-9));
  });
}
