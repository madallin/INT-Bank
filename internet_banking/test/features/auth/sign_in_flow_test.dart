import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/network/dio_client.dart';
import 'package:internet_banking/features/auth/onboarding_session.dart';
import 'package:internet_banking/features/auth/screens/pin_screen.dart';
import 'package:internet_banking/features/home/screens/home_screen.dart';
import 'package:internet_banking/features/onboarding/screens/approval_screen.dart';
import 'package:internet_banking/features/onboarding/screens/tos_screen.dart';
import 'package:internet_banking/widgets/pin_pad.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// Sign-in after the server stopped accepting device tokens on customer routes: the SMS
/// step returns an onboarding token, and the PIN is checked by phone + PIN sign-in.
void main() {
  setUpAll(setUpTestApp);

  const phone = '+40712345678';
  const verified = {
    'success': true,
    'preAuthToken': 'pre-auth-token',
    'userId': 1,
    'acceptedTerms': true,
    'approved': true,
    'hasPin': false,
  };

  group('OnboardingSession', () {
    test('reads the SMS verification reply', () {
      final session = OnboardingSession.fromVerifyResponse(verified, phone)!;
      expect(session.userId, 1);
      expect(session.authHeader, {'Authorization': 'Bearer pre-auth-token'});
      expect(OnboardingSession.fromVerifyResponse({'success': true}, phone), isNull,
          reason: 'no token means the phone is not a customer');
    });

    test('goes to terms, then approval, then the PIN', () {
      final base = OnboardingSession.fromVerifyResponse(verified, phone)!;
      expect(base.copyWith(acceptedTerms: false).nextScreen(), isA<TosScreen>());
      expect(base.copyWith(approved: false).nextScreen(), isA<ApprovalScreen>());
      final pin = base.nextScreen() as PinScreen;
      expect(pin.set, isTrue);
      expect(pin.preAuthToken, 'pre-auth-token');
      expect((base.copyWith(hasPin: true).nextScreen() as PinScreen).set, isFalse);
    });
  });

  Future<void> typePin(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.descendant(of: find.byType(PinPad), matching: find.text(d)));
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('the first PIN is saved with the onboarding token, then the customer is signed in', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    final api = demoCustomerApi()
      ..routes['PUT /users/1/set-pin'] = {'success': true}
      ..routes['POST /auth-session/login'] = {'accessToken': 'access', 'refreshToken': 'refresh', 'userId': 1};
    api.install();

    await tester.pumpWidget(testApp(const PinScreen(
        userId: 1, set: true, popOnSuccess: false, useJwtLogin: true, phoneNumber: phone, preAuthToken: 'pre-auth-token')));
    await settle(tester);
    await typePin(tester, '246802');
    await typePin(tester, '246802');
    await tester.pump(const Duration(seconds: 1));

    final setPin = api.calls.indexOf('PUT /users/1/set-pin');
    expect(setPin, isNot(-1));
    expect(api.sentAuth[setPin], 'Bearer pre-auth-token');
    expect(api.calls, contains('POST /auth-session/login'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a wrong existing PIN shows the attempts left and stays on the PIN screen', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    FakeApi({
      'POST /auth-session/login': const FakeResponse(401, {'code': 'SCA_PIN_INVALID', 'error': 'PIN incorect', 'remainingAttempts': 2}),
    }).install();

    await tester.pumpWidget(testApp(const PinScreen(userId: 1, set: false, useJwtLogin: true, phoneNumber: phone)));
    await settle(tester);
    await typePin(tester, '111111');

    expect(find.text('PIN incorect. Mai ai 2 încercări.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('choosing a PIN without the SMS step is refused before any request', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    final api = FakeApi({})..install();

    await tester.pumpWidget(testApp(const PinScreen(userId: 1, set: true, phoneNumber: phone)));
    await settle(tester);
    await typePin(tester, '246802');
    await typePin(tester, '246802');

    expect(api.calls.where((c) => c.contains('set-pin')), isEmpty);
    expect(find.text('Eroare la autentificare. Încearcă din nou.'), findsOneWidget);
  });

  testWidgets("a request's own token is not replaced by a stored session", (tester) async {
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'someone-elses-session'});
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final api = FakeApi({'GET /users/1/has-pin': {'hasPin': true}})..install();

    await tester.runAsync(() => DioClient().get('/users/1/has-pin',
        options: Options(headers: {'Authorization': 'Bearer pre-auth-token'})));
    await tester.runAsync(() => DioClient().get('/users/1/has-pin'));

    expect(api.sentAuth, ['Bearer pre-auth-token', 'Bearer someone-elses-session']);
  });
}
