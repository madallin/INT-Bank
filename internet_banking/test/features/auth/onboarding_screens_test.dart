import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/auth/onboarding_session.dart';
import 'package:internet_banking/features/auth/screens/login_screen.dart';
import 'package:internet_banking/features/auth/screens/pin_screen.dart';
import 'package:internet_banking/features/auth/screens/two_factor_screen.dart';
import 'package:internet_banking/features/home/widgets/open_currency_account_dialog.dart';
import 'package:internet_banking/features/onboarding/screens/approval_screen.dart';
import 'package:internet_banking/features/onboarding/screens/tos_screen.dart';
import 'package:internet_banking/features/transfer/widgets/saved_beneficiaries_bottom_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

const _session = OnboardingSession(
  userId: 5,
  phoneNumber: '+40712345678',
  preAuthToken: 'pre-auth-token',
  acceptedTerms: false,
  approved: true,
  hasPin: false,
);

/// Opens [open] from a button so dialogs and sheets have a route to sit on.
Widget _launcher(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => open(context), child: const Text('open')))),
    );

/// A device without network: every connection fails like a real offline socket would.
class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineHttpClient();
}

class _OfflineHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw const SocketException('offline (test)');
}

void main() {
  setUpAll(() {
    setUpTestApp();
    fakePhonePlugin();
  });

  HttpOverrides? previousOverrides;
  setUp(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _OfflineHttpOverrides();
  });
  tearDown(() => HttpOverrides.global = previousOverrides);

  group('LoginScreen', () {
    testWidgets('a known number goes to the SMS step first', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      final api = FakeApi({
        'POST /login': {'exists': true, 'userId': 5, 'approved': false, 'acceptedterms': false},
      })..install();

      await tester.pumpWidget(testApp(const LoginScreen()));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '712345678');
      await tester.tap(find.text('Confirmă'));
      await settle(tester);

      final i = api.calls.indexOf('POST /login');
      expect(i, isNot(-1));
      expect((api.sentBodies[i] as Map)['phone'], '+40712345678');
      // Even with terms and approval pending, the phone is proven before anything else.
      expect(find.byType(TwoFactorScreen), findsOneWidget);
    });

    testWidgets('an unknown number is explained', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      FakeApi({'POST /login': {'exists': false}}).install();

      await tester.pumpWidget(testApp(const LoginScreen()));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '712345678');
      await tester.tap(find.text('Confirmă'));
      await settle(tester);

      expect(find.text('Numărul de telefon nu aparține unui client'), findsOneWidget);
      expect(find.byType(TwoFactorScreen), findsNothing);
    });
  });

  group('TosScreen', () {
    Future<void> acceptAfterReading(WidgetTester tester) async {
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -20000));
      await settle(tester);
      await tester.tap(find.byType(ElevatedButton));
      await settle(tester);
    }

    testWidgets('accepts with the onboarding token, then continues to the PIN', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      final api = FakeApi({
        'PUT /users/5/accept-tos': {'success': true},
        'GET /users/5/has-approved': {'contaprobat': true},
      })..install();

      await tester.pumpWidget(testApp(const TosScreen(userId: 5, session: _session)));
      await settle(tester);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull,
          reason: 'the terms must be read to the end first');
      await acceptAfterReading(tester);

      final accept = api.calls.indexOf('PUT /users/5/accept-tos');
      expect(accept, isNot(-1));
      expect(api.sentAuth[accept], 'Bearer pre-auth-token');
      final pin = tester.widget<PinScreen>(find.byType(PinScreen));
      expect(pin.set, isTrue);
      expect(pin.preAuthToken, 'pre-auth-token');
    });

    testWidgets('waits for approval when the account is not approved yet', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      FakeApi({
        'PUT /users/5/accept-tos': {'success': true},
        'GET /users/5/has-approved': {'contaprobat': false},
      }).install();

      await tester.pumpWidget(testApp(const TosScreen(userId: 5, session: _session)));
      await settle(tester);
      await acceptAfterReading(tester);

      expect(find.byType(ApprovalScreen), findsOneWidget);
    });

    testWidgets('without the SMS step the customer is sent to sign in', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      final api = FakeApi({})..install();

      await tester.pumpWidget(testApp(const TosScreen(userId: 5)));
      await settle(tester);
      await acceptAfterReading(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(api.calls.where((c) => c.contains('accept-tos')), isEmpty);
    });
  });

  testWidgets('ApprovalScreen asks the bank with the onboarding token and celebrates approval', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    final api = FakeApi({'GET /users/5/has-approved': {'contaprobat': true}})..install();

    await tester.pumpWidget(testApp(const ApprovalScreen(userId: 5, preAuthToken: 'pre-auth-token')));
    expect(find.text('Verificare în curs'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 2));
    }

    final poll = api.calls.indexOf('GET /users/5/has-approved');
    expect(poll, isNot(-1));
    expect(api.sentAuth[poll], 'Bearer pre-auth-token');
    expect(find.text('Cont verificat cu succes!'), findsOneWidget);

    // Leave the screen before its delayed navigation fires.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('saved beneficiaries are listed and one can be picked', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    demoCustomerApi().install();
    String? picked;

    await tester.pumpWidget(testApp(_launcher(
      (context) => SavedBeneficiariesBottomSheet.show(context, userId: 1, onSelect: (name, iban) => picked = iban),
    )));
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.text('ANA IONESCU'), findsOneWidget);
    await tester.tap(find.text('ANA IONESCU'));
    await settle(tester);
    expect(picked, isNotNull);
  });

  testWidgets('opening a currency account sends the chosen currency', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 900));
    final api = FakeApi({
      'POST /users/1/accounts': const FakeResponse(201, {'success': true, 'account': {'id': 103, 'moneda': 'USD'}}),
    })..install();
    var created = false;

    await tester.pumpWidget(testApp(_launcher(
      (context) => OpenCurrencyAccountDialog.show(context, userId: 1, onAccountCreated: () => created = true),
    )));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.textContaining('(USD)'));
    await tester.pump();
    await tester.tap(find.text('Deschide'));
    await settle(tester);

    final i = api.calls.indexOf('POST /users/1/accounts');
    expect(api.sentBodies[i], {'currency': 'USD'});
    expect(created, isTrue);
  });
}
