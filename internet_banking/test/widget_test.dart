import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:internet_banking/core/security/banking_security_wrapper.dart';
import 'package:internet_banking/core/settings/app_settings.dart';
import 'package:internet_banking/main.dart';

import 'support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);
  tearDown(AppSettings.instance.debugReset);

  testWidgets('App renders MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Let the splash finish its checks
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('the whole app follows the choices made on the Profile tab', timeout: const Timeout(Duration(seconds: 60)), (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);
    expect(app().locale, isNull);

    await tester.runAsync(() async {
      await AppSettings.instance.setThemeMode(ThemeMode.dark);
      await AppSettings.instance.setLocale(const Locale('en'));
      await AppSettings.instance.setAutoLockMinutes(1);
    });
    await tester.pump();

    expect(app().themeMode, ThemeMode.dark);
    expect(app().locale, const Locale('en'));
    expect(tester.widget<BankingSecurityWrapper>(find.byType(BankingSecurityWrapper)).timeout, const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 5));
  });
}
