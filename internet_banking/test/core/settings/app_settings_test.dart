import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/config/app_config.dart';
import 'package:internet_banking/core/security/banking_security_wrapper.dart';
import 'package:internet_banking/core/security/session_timeout_service.dart';
import 'package:internet_banking/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);
  tearDown(AppSettings.instance.debugReset);

  test('defaults follow the phone and lock after 5 minutes', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();

    expect(AppSettings.instance.themeMode, ThemeMode.system);
    expect(AppSettings.instance.locale, isNull);
    expect(AppSettings.instance.autoLock, const Duration(minutes: 5));
  });

  test('saved choices come back on the next start', () async {
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': 'light',
      'settings.language': 'ro',
      'settings.autoLockMinutes': 2,
    });
    await AppSettings.instance.load();

    expect(AppSettings.instance.themeMode, ThemeMode.light);
    expect(AppSettings.instance.locale, const Locale('ro'));
    expect(AppSettings.instance.autoLockMinutes, 2);
  });

  test('stored values the app does not offer are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': 'sepia',
      'settings.language': 'de',
      'settings.autoLockMinutes': 60,
    });
    await AppSettings.instance.load();
    await AppSettings.instance.setAutoLockMinutes(30);

    expect(AppSettings.instance.themeMode, ThemeMode.system);
    expect(AppSettings.instance.locale, isNull);
    expect(AppSettings.instance.autoLockMinutes, 5, reason: 'never longer than the choices offered');
  });

  testWidgets('a new auto-lock time takes effect without restarting the app', (tester) async {
    Widget app(Duration timeout) => Directionality(
          textDirection: TextDirection.ltr,
          child: BankingSecurityWrapper(timeout: timeout, child: const SizedBox()),
        );
    await tester.pumpWidget(app(const Duration(minutes: 5)));
    expect(SessionTimeoutService.instance.timeout, const Duration(minutes: 5));

    await tester.pumpWidget(app(const Duration(minutes: 1)));
    expect(SessionTimeoutService.instance.timeout, const Duration(minutes: 1));
  });

  test('the version on the Profile tab matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(AppConfig.appVersion, version);
  });
}
