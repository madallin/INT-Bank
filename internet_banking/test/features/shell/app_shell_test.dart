import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/accounts/screens/account_detail_screen.dart';
import 'package:internet_banking/features/home/widgets/home_vaults_banner.dart';
import 'package:internet_banking/features/shell/app_shell.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';
import 'package:internet_banking/features/vaults/screens/vaults_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// The signed-in app: bottom navigation between Home, Accounts, Payments, Savings and Profile.
void main() {
  setUpAll(setUpTestApp);

  Future<FakeApi> openShell(WidgetTester tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    final api = demoCustomerApi()..install();
    await tester.pumpWidget(testApp(const AppShell(userId: 1)));
    await settle(tester);
    return api;
  }

  int selectedTab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> openTab(WidgetTester tester, AppTab tab) async {
    await tester.tap(find.byKey(ValueKey('nav-${tab.name}')));
    await settle(tester);
  }

  testWidgets('starts on Home and builds other tabs only when opened', (tester) async {
    final api = await openShell(tester);

    expect(selectedTab(tester), AppTab.home.index);
    expect(api.calls, isNot(contains('GET /users/1/accounts')), reason: 'Accounts not opened yet');

    await openTab(tester, AppTab.accounts);
    expect(api.calls, contains('GET /users/1/accounts'));
    await openTab(tester, AppTab.profile);
    expect(find.text('Ion Popescu'), findsOneWidget);
  });

  testWidgets('Accounts lists every account and opens one with its IBAN to copy', (tester) async {
    await openShell(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await openTab(tester, AppTab.accounts);
    expect(find.text('Cont curent RON'), findsOneWidget);
    expect(find.text('Cont curent EUR'), findsOneWidget);

    await tester.tap(find.text('Cont curent EUR'));
    await settle(tester);
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(find.text('840,50 EUR'), findsOneWidget);

    await tester.tap(find.byTooltip('Copiază IBAN-ul'));
    await tester.pump();
    expect(copied, 'RO49INTB0001EUR3F9A01BC');
    expect(find.text('IBAN copiat'), findsOneWidget);
  });

  testWidgets('Payments pays from the account the customer picks', (tester) async {
    await openShell(tester);
    await openTab(tester, AppTab.payments);

    await tester.tap(find.text('Cont curent EUR'));
    await tester.pump();
    await tester.tap(find.text('Transfer către un cont INTBank'));
    await settle(tester);

    final transfer = tester.widget<TransferScreen>(find.byType(TransferScreen));
    expect(transfer.userIban, 'RO49INTB0001EUR3F9A01BC');
    expect(transfer.currency, 'EUR');
    expect(transfer.availableBalance, 840.5);
  });

  testWidgets("Home's savings banner opens the Savings tab", (tester) async {
    await openShell(tester);

    await tester.ensureVisible(find.byType(HomeVaultsBanner));
    await tester.tap(find.byType(HomeVaultsBanner));
    await settle(tester);

    expect(selectedTab(tester), AppTab.savings.index);
    expect(find.byType(VaultsScreen), findsOneWidget);
    expect(find.byTooltip('Înapoi'), findsNothing, reason: 'a tab has nowhere to go back to');
  });

  testWidgets('Android back on another tab returns to Home instead of closing the app', (tester) async {
    await openShell(tester);
    await openTab(tester, AppTab.payments);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(selectedTab(tester), AppTab.home.index);
  });

  testWidgets('coming back to a tab refreshes it, so a payment made elsewhere shows', (tester) async {
    final api = await openShell(tester);
    int count(String call) => api.calls.where((c) => c == call).length;
    final homeLoads = count('GET /users/1/cards');

    await openTab(tester, AppTab.accounts);
    final accountLoads = count('GET /users/1/accounts');
    expect(count('GET /users/1/cards'), homeLoads, reason: 'a hidden tab does not reload');

    await openTab(tester, AppTab.home);
    expect(count('GET /users/1/cards'), greaterThan(homeLoads));

    await openTab(tester, AppTab.accounts);
    expect(count('GET /users/1/accounts'), greaterThan(accountLoads));
  });
}
