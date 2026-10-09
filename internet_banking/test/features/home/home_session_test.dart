import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/home/screens/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// Home talks to the bank with the signed-in session. Device tokens open nothing on the
/// server, so Home must never send one.
void main() {
  setUpAll(setUpTestApp);

  testWidgets('every request Home makes carries the session token', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'session-token'});
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    usePhoneViewport(tester, size: const Size(400, 1600));
    final api = demoCustomerApi()..install();

    await tester.pumpWidget(testApp(const HomeScreen(userId: 1)));
    await settle(tester);

    final customerCalls = [
      for (var i = 0; i < api.calls.length; i++)
        if (api.calls[i].contains('/users/1/')) i,
    ];
    expect(customerCalls, isNotEmpty);
    for (final i in customerCalls) {
      expect(api.sentAuth[i], 'Bearer session-token', reason: api.calls[i]);
    }
    expect(api.calls, isNot(contains('POST /auth/get-client-token')));
    expect(find.textContaining('12.345,67'), findsWidgets, reason: 'the balance loaded');
  });

  testWidgets('Home greets the customer by first name', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    demoCustomerApi().install();

    await tester.pumpWidget(testApp(const HomeScreen(userId: 1)));
    await settle(tester);

    expect(find.textContaining(RegExp(r'^(Bună dimineața|Bună ziua|Bună seara), Ion$')), findsOneWidget);
  });
}
