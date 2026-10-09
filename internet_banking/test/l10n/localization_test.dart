import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/home/screens/home_screen.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';
import 'package:internet_banking/features/transfer/transfer_form_validator.dart';
import 'package:internet_banking/l10n/l10n.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Map<String, dynamic> readArb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> placeholders(String message) => RegExp(
  r'\{(\w+)(?:,|\})',
).allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  group('ARB files', () {
    final ro = readArb('ro');
    final en = readArb('en');
    final keys = ro.keys.where((k) => !k.startsWith('@')).toSet();

    test('English translates every Romanian message and nothing else', () {
      expect(en.keys.where((k) => !k.startsWith('@')).toSet(), keys);
    });

    test('translations keep the same placeholders', () {
      for (final key in keys) {
        expect(
          placeholders(en[key] as String),
          placeholders(ro[key] as String),
          reason: key,
        );
      }
    });

    test('no message is empty', () {
      for (final key in keys) {
        expect((ro[key] as String).trim(), isNotEmpty, reason: 'ro $key');
        expect((en[key] as String).trim(), isNotEmpty, reason: 'en $key');
      }
    });
  });

  group('plurals', () {
    final ro = lookupAppLocalizations(const Locale('ro'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('Romanian uses one / few / "de" forms', () {
      expect(ro.historyResultsCount(1), '1 tranzacție găsită');
      expect(ro.historyResultsCount(3), '3 tranzacții găsite');
      expect(ro.historyResultsCount(20), '20 de tranzacții găsite');
      expect(ro.analyticsPlati(1), '1 plată');
      expect(ro.analyticsPlati(9), '9 plăți');
    });

    test('English uses singular / plural', () {
      expect(en.historyResultsCount(1), '1 transaction found');
      expect(en.historyResultsCount(3), '3 transactions found');
      expect(en.beneficiariesContacte(1), '1 contact');
    });
  });

  group('locale resolution', () {
    const supported = AppLocalizations.supportedLocales;

    test('follows a supported phone language', () {
      expect(
        AppL10n.resolve(const Locale('ro', 'RO'), supported).languageCode,
        'ro',
      );
      expect(
        AppL10n.resolve(const Locale('en', 'GB'), supported).languageCode,
        'en',
      );
    });

    test('falls back to English otherwise', () {
      expect(AppL10n.resolve(const Locale('de'), supported).languageCode, 'en');
      expect(AppL10n.resolve(null, supported).languageCode, 'en');
    });
  });

  group('English UI', () {
    setUpAll(setUpTestApp);
    tearDown(() => AppL10n.update(lookupAppLocalizations(const Locale('ro'))));

    testWidgets('transfer form and its validation are in English', (
      tester,
    ) async {
      demoCustomerApi().install();
      usePhoneViewport(tester, size: const Size(360, 1400));
      await tester.pumpWidget(
        testApp(
          const TransferScreen(
            userId: 1,
            userIban: 'RO49INTB0001RON0000000001',
            availableBalance: 100,
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();
      expect(find.text('Recipient IBAN'), findsOneWidget);
      await tester.ensureVisible(find.text('Send now'));
      await tester.tap(find.text('Send now'));
      await tester.pump();
      expect(find.text("Enter the recipient's IBAN."), findsOneWidget);
      expect(
        TransferFormValidator.amount(0),
        'Enter an amount greater than 0.',
      );
      await settle(tester); // the recent-recipients request finishes
    });

    testWidgets('home is in English', (tester) async {
      demoCustomerApi().install();
      usePhoneViewport(tester);
      final previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      await tester.pumpWidget(
        testApp(const HomeScreen(userId: 1), locale: const Locale('en')),
      );
      await settle(tester, rounds: 10);
      FlutterError.onError = previous;
      expect(find.text('Available balance'), findsOneWidget);
      expect(find.text('Recent transactions'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
