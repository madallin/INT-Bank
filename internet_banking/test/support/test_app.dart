import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internet_banking/l10n/l10n.dart';
import 'package:internet_banking/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same fonts setup as `main.dart`, plus empty plugin storage for tests.
void setUpTestApp()
{
  GoogleFonts.config.allowRuntimeFetching = false;
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
}

/// Wraps [home] like the real app: app theme and localizations (Romanian
/// unless [locale] says otherwise).
Widget testApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Locale locale = const Locale('ro'),
})
{
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Builder(builder: (context) {
        AppL10n.update(AppLocalizations.of(context));
        return child!;
      }),
    ),
    home: home,
  );
}

/// Lets screens finish their initial requests: async work runs on the real
/// clock while timers (retries, animations) run on the fake one.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async
{
  for(var i = 0; i < rounds; i++)
  {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Sets a phone-sized logical viewport for the current test.
void usePhoneViewport(WidgetTester tester, {Size size = const Size(360, 780)})
{
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
