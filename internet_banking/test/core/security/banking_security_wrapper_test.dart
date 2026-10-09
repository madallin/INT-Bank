import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/banking_security_wrapper.dart';
import 'package:internet_banking/core/security/session_timeout_service.dart';
import 'package:internet_banking/features/auth/screens/pin_screen.dart';
import 'package:internet_banking/l10n/l10n.dart';
import 'package:internet_banking/theme/app_theme.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// Wraps the app the way main.dart does: one navigator, the wrapper above it.
Widget _app(GlobalKey<NavigatorState> key) => MaterialApp(
      navigatorKey: key,
      theme: AppTheme.light(),
      locale: const Locale('ro'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(body: Text('Protected Bank Content')),
      builder: (context, child) {
        AppL10n.update(AppLocalizations.of(context));
        return BankingSecurityWrapper(navigatorKey: key, child: child!);
      },
    );

void main() {
  setUpAll(setUpTestApp);

  testWidgets('a signed-in session is ended after inactivity and needs the PIN again', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'accessToken': 'access', 'refreshToken': 'refresh', 'userId': '1', 'phone': '+40712345678',
    });
    final api = FakeApi({'POST /auth-session/logout': {'success': true}})..install();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(key));

    SessionTimeoutService.instance.lockSession();
    await settle(tester);

    expect(find.text('Sesiune încheiată'), findsOneWidget);
    expect(api.calls, contains('POST /auth-session/logout'), reason: 'the session ends on the server');

    await tester.tap(find.text('Introdu PIN-ul'));
    await settle(tester);
    expect(find.text('Sesiune încheiată'), findsNothing);
    expect(tester.widget<PinScreen>(find.byType(PinScreen)).phoneNumber, '+40712345678');
    expect(find.text('Protected Bank Content'), findsNothing, reason: 'the protected screens are gone');
  });

  testWidgets('nothing is locked when nobody is signed in', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(_app(GlobalKey<NavigatorState>()));

    SessionTimeoutService.instance.lockSession();
    await settle(tester);

    expect(find.text('Sesiune încheiată'), findsNothing);
    expect(find.text('Protected Bank Content'), findsOneWidget);
  });

  testWidgets('the app switcher sees a privacy veil, not balances', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(_app(GlobalKey<NavigatorState>()));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('INTBank • Protecția confidențialității'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('INTBank • Protecția confidențialității'), findsNothing);
  });
}
