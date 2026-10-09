import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/error/misconfigured_app.dart';
import 'features/splash/splash_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/network/transport_security.dart';
import 'core/security/banking_security_wrapper.dart';
import 'core/settings/app_settings.dart';
import 'l10n/l10n.dart';
import 'core/security/screen_security_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Fonts ship in assets/google_fonts; never fetch them from Google at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter', 'Poppins', 'SpaceMono']) {
      final licence = await rootBundle.loadString(
        'assets/google_fonts/$family-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks(['google_fonts', family], licence);
    }
  });

  await AppSettings.instance.load();

  // Request native screen capture / recording protection
  await ScreenSecurityService.instance.enableSecureScreen();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // A release build without certificate pins must not talk to the bank at all.
  if (TransportPolicy.mode == TransportSecurity.misconfigured) {
    runApp(const MisconfiguredApp());
    return;
  }

  runApp(const MyApp());
}

/// The app's single navigator (also used by the inactivity lock).
final appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'INTBank',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // The phone's light/dark setting unless the customer picked one on the Profile tab;
        // every screen reads its colours from AppColors (contrast is checked in test/theme).
        themeMode: settings.themeMode,
        // The phone's language (Romanian or English, else English) unless the customer
        // picked one; also localizes Material widgets such as date pickers.
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: AppL10n.resolve,
        navigatorKey: appNavigatorKey,
        home: const SplashScreen(),
        // Status-bar icons follow the active theme (dark icons on light screens).
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                ),
          child: Builder(
            builder: (context) {
              // Keeps strings used outside widgets in the active language.
              AppL10n.update(AppLocalizations.of(context));
              return BankingSecurityWrapper(
                navigatorKey: appNavigatorKey,
                timeout: settings.autoLock,
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }
}
