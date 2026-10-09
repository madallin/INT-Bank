import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/auth/screens/login_screen.dart';
import 'package:internet_banking/features/auth/screens/register_screen.dart';
import 'package:internet_banking/features/welcome/welcome_screen.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(() {
    setUpTestApp();
    fakePhonePlugin();
  });

  testWidgets('says what INTBank offers, then opens an account or signs in', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    FakeApi({}).install();
    await tester.pumpWidget(testApp(const WelcomeScreen()));

    expect(find.text('Banca ta, mereu cu tine'), findsOneWidget);
    expect(find.text('Transferuri instant'), findsOneWidget);
    expect(find.text('Seifuri de economii'), findsOneWidget);
    expect(find.text('Securitate la fiecare pas'), findsOneWidget);

    await tester.tap(find.text('Deschide un cont'));
    await settle(tester);
    expect(find.byType(RegisterScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(RegisterScreen))).pop();
    await settle(tester);
    await tester.tap(find.text('Am deja cont'));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('is in English too', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    await tester.pumpWidget(testApp(const WelcomeScreen(), locale: const Locale('en')));

    expect(find.text('Your bank, always with you'), findsOneWidget);
    expect(find.text('Open an account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
