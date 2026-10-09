import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/services/privacy_mode_service.dart';
import 'package:internet_banking/core/settings/app_settings.dart';
import 'package:internet_banking/core/storage/secure_session_manager.dart';
import 'package:internet_banking/features/profile/screens/change_pin_screen.dart';
import 'package:internet_banking/features/profile/screens/profile_screen.dart';
import 'package:internet_banking/features/welcome/welcome_screen.dart';
import 'package:internet_banking/widgets/pin_pad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.debugReset();
  });
  tearDown(() async {
    AppSettings.instance.debugReset();
    await PrivacyModeService().setPrivacyMode(false);
  });

  Future<FakeApi> openProfile(WidgetTester tester, {Map<String, Object> extra = const {}}) async {
    usePhoneViewport(tester, size: const Size(400, 1800));
    final api = demoCustomerApi();
    api.routes.addAll(extra);
    api.install();
    await tester.pumpWidget(testApp(const ProfileScreen(userId: 1)));
    await settle(tester);
    return api;
  }

  Future<void> choose(WidgetTester tester, String row, String option) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  group('Profile', () {
    testWidgets("shows the customer's details from the bank", (tester) async {
      await openProfile(tester);

      expect(find.text('Ion Popescu'), findsOneWidget);
      expect(find.text('+40 712 345 678'), findsOneWidget);
      expect(find.text('ion.popescu@example.com'), findsOneWidget);
      expect(find.text('Str. Memorandumului 28, Cluj-Napoca, Cluj'), findsOneWidget);
      expect(find.text('12.04.1990'), findsOneWidget);
    });

    testWidgets('theme, language and auto-lock choices are applied and remembered', (tester) async {
      await openProfile(tester);

      await choose(tester, 'Aspect', 'Întunecat');
      await choose(tester, 'Blocare automată', 'După 1 minut fără activitate');
      await choose(tester, 'Limbă', 'English');

      final settings = AppSettings.instance;
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.autoLock, const Duration(minutes: 1));
      expect(settings.locale, const Locale('en'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.themeMode'), 'dark');
      expect(prefs.getInt('settings.autoLockMinutes'), 1);
      expect(prefs.getString('settings.language'), 'en');

      // Back to following the phone.
      await choose(tester, 'Limbă', 'Limba telefonului');
      expect(settings.locale, isNull);
      expect(prefs.getString('settings.language'), isNull);
    });

    testWidgets('the hide-amounts switch is the same setting as the eye on Home', (tester) async {
      await openProfile(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(PrivacyModeService().isPrivacyModeEnabled.value, isTrue);
    });

    testWidgets('signing out ends the session on the server and on the phone', (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'accessToken': 'access', 'refreshToken': 'refresh', 'userId': '1', 'phone': '+40712345678',
      });
      addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
      final api = await openProfile(tester, extra: {'POST /auth-session/logout': {'success': true}});

      await tester.tap(find.text('Deconectare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deconectează-mă'));
      await settle(tester);

      final logout = api.calls.indexOf('POST /auth-session/logout');
      expect(logout, isNot(-1));
      expect(api.sentBodies[logout], {'refreshToken': 'refresh'});
      expect(await SecureSessionManager.getAccessToken(), isNull);
      expect(await SecureSessionManager.getRefreshToken(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('Change PIN', () {
    /// Opens the screen from a launcher, so a successful change can close it.
    Future<FakeApi> openChangePin(WidgetTester tester, Object setPinReply) async {
      usePhoneViewport(tester, size: const Size(400, 900));
      final api = FakeApi({'PUT /users/1/set-pin': setPinReply})..install();
      await tester.pumpWidget(testApp(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePinScreen(userId: 1))),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> enter(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        tester.widget<PinPad>(find.byType(PinPad)).onDigit(digit);
        await tester.pump();
      }
    }

    testWidgets('sends the current PIN with the new one, then closes', (tester) async {
      final api = await openChangePin(tester, {'success': true});

      expect(find.text('Pasul 1 din 3'), findsOneWidget);
      await enter(tester, '111111');
      expect(find.text('Alege noul PIN'), findsOneWidget);
      await enter(tester, '246802');
      expect(find.text('Confirmă noul PIN'), findsOneWidget);
      await enter(tester, '246802');
      await settle(tester);

      expect(api.sentBodies.single, {'codPin': '246802', 'currentPin': '111111'});
      expect(find.byType(ChangePinScreen), findsNothing);
      expect(find.text('PIN-ul a fost schimbat.'), findsOneWidget);
    });

    testWidgets('refuses the same PIN and a confirmation that does not match', (tester) async {
      final api = await openChangePin(tester, {'success': true});

      await enter(tester, '111111');
      await enter(tester, '111111');
      expect(find.text('Noul PIN trebuie să fie diferit de cel actual.'), findsOneWidget);
      expect(find.text('Pasul 2 din 3'), findsOneWidget);

      await enter(tester, '246802');
      await enter(tester, '246803');
      expect(find.text('PIN-urile nu coincid'), findsOneWidget);
      expect(find.text('Pasul 2 din 3'), findsOneWidget);
      expect(api.calls, isEmpty, reason: 'nothing is sent until both entries match');
    });

    testWidgets('a wrong current PIN starts again from the first step', (tester) async {
      await openChangePin(tester, const FakeResponse(400, {'code': 'SCA_PIN_INVALID', 'remainingAttempts': 2}));

      await enter(tester, '999999');
      await enter(tester, '246802');
      await enter(tester, '246802');
      await settle(tester);

      expect(find.text('PIN incorect. Mai ai 2 încercări.'), findsOneWidget);
      expect(find.text('Pasul 1 din 3'), findsOneWidget);
      expect(find.byType(ChangePinScreen), findsOneWidget);
    });
  });
}
