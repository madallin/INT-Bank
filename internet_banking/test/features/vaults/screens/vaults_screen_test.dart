import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/vaults/screens/vaults_screen.dart';
import 'package:internet_banking/widgets/app_button.dart';

import '../../../support/fake_api.dart';
import '../../../support/test_app.dart';

/// Vaults are server-backed: every balance comes from the bank and every change is a request.
void main() {
  setUpAll(setUpTestApp);

  Future<FakeApi> open(WidgetTester tester, {Map<String, Object> extra = const {}}) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    final api = demoCustomerApi()..routes.addAll(extra);
    api.install();
    await tester.pumpWidget(testApp(const VaultsScreen(userId: 1)));
    await settle(tester);
    return api;
  }

  Finder inCard(int vaultId, Finder finder) =>
      find.descendant(of: find.byKey(ValueKey('vault-$vaultId')), matching: finder);

  testWidgets('shows the vaults the bank holds, with totals, progress and lock state', (tester) async {
    await open(tester);

    expect(find.text('6.200,00 RON'), findsOneWidget, reason: 'total saved across vaults');
    expect(find.text('Vacanță'), findsOneWidget);
    expect(find.text('1.200,00 RON din 3.000,00 RON'), findsOneWidget);
    expect(find.text('Flexibil'), findsOneWidget);
    expect(find.text('Blocat până la 31.12.2027'), findsOneWidget);
    expect(find.textContaining('nu sunt purtătoare de dobândă'), findsOneWidget);
  });

  testWidgets('a locked vault cannot be withdrawn from', (tester) async {
    await open(tester);

    final flexible = tester.widget<AppButton>(inCard(31, find.widgetWithText(AppButton, 'Retrage')));
    final locked = tester.widget<AppButton>(inCard(32, find.widgetWithText(AppButton, 'Retrage')));
    expect(flexible.onPressed, isNotNull);
    expect(locked.onPressed, isNull);

    final lockedWithdraw = inCard(32, find.text('Retrage'));
    await tester.ensureVisible(lockedWithdraw);
    await tester.tap(lockedWithdraw);
    await tester.pumpAndSettle();
    expect(find.text('Retrage din „Avans casă”'), findsNothing);
  });

  testWidgets('adding money checks the amount, then sends it and reloads', (tester) async {
    final api = await open(tester, extra: {
      'POST /users/1/vaults/31/deposit': {
        'success': true,
        'vault': {'id': 31, 'name': 'Vacanță', 'balance': 1450.0, 'targetAmount': 3000.0, 'currency': 'RON', 'lockType': 'FLEXIBLE', 'lockedToday': false},
      },
    });

    final deposit = inCard(31, find.text('Depune'));
    await tester.ensureVisible(deposit);
    await tester.tap(deposit);
    await tester.pumpAndSettle();
    expect(find.text('Depune în „Vacanță”'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '999999');
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Suma depășește'), findsOneWidget);
    expect(api.calls, isNot(contains('POST /users/1/vaults/31/deposit')));

    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('Confirmă'));
    await settle(tester);

    final i = api.calls.indexOf('POST /users/1/vaults/31/deposit');
    expect(i, isNot(-1));
    expect(api.sentBodies[i], {'accountId': 101, 'amount': 250.0});
    expect(find.textContaining('Ai depus 250,00 RON'), findsOneWidget);
    expect(api.calls.where((c) => c == 'GET /users/1/vaults'), hasLength(2), reason: 'reloaded after the change');
  });

  testWidgets('a locked vault needs a target date before it is created', (tester) async {
    final api = await open(tester, extra: {
      'POST /users/1/vaults': const FakeResponse(201, {
        'success': true,
        'vault': {'id': 40, 'name': 'Mașină', 'balance': 0, 'targetAmount': 15000.0, 'currency': 'RON', 'lockType': 'LOCKED', 'lockedToday': true},
      }),
    });

    await tester.tap(find.text('Seif nou'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Numele seifului'), 'Mașină');
    await tester.enterText(find.widgetWithText(TextField, 'Suma țintă (RON)'), '15000');
    await tester.tap(find.text('Blocat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Creează seiful'));
    await tester.tap(find.text('Creează seiful'));
    await tester.pumpAndSettle();

    expect(find.text('Un seif blocat are nevoie de o dată țintă.'), findsOneWidget);
    expect(api.calls, isNot(contains('POST /users/1/vaults')));
  });

  testWidgets('shows a retry when the vaults cannot be loaded', (tester) async {
    usePhoneViewport(tester);
    FakeApi({}).install();
    await tester.pumpWidget(testApp(const VaultsScreen(userId: 1)));
    await settle(tester);

    expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    expect(find.text('Seif nou'), findsNothing);
  });
}
