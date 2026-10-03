import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/security/banking_security_wrapper.dart';
import 'l10n/l10n.dart';
import 'core/security/screen_security_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Fonts ship in assets/google_fonts; never fetch them from Google at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter', 'Poppins', 'SpaceMono'])
    {
      final licence = await rootBundle.loadString('assets/google_fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts', family], licence);
    }
  });

  // Request native screen capture / recording protection
  await ScreenSecurityService.instance.enableSecureScreen();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref)
  {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'INT Bank',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Locked to light until every screen reads colours from AppColors
      // (UI plan, Phase 3); the dark tokens are already defined.
      themeMode: ThemeMode.light,
      // Follows the phone's language (Romanian or English, else English);
      // also localizes Material widgets such as date pickers.
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: AppL10n.resolve,
      routerConfig: appRouter,
      // Status-bar icons follow the active theme (dark icons on light screens).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: Builder(
          builder: (context) {
            // Keeps strings used outside widgets in the active language.
            AppL10n.update(AppLocalizations.of(context));
            return BankingSecurityWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
