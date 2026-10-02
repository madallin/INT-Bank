import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/app_config.dart';
import 'core/security/screen_security_service.dart';
import 'router/app_router.dart';

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

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
    final baseFont = GoogleFonts.inter();

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: const Color(lightForestGreenColor),
        secondary: const Color(0xFF0284C7),
        surface: const Color(0xFFF8FAFC),
        onPrimary: Colors.white,
        onSurface: const Color(darkGreyColor),
        outline: Colors.grey[300]!,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      fontFamily: baseFont.fontFamily,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E676),
        secondary: Color(0xFF38BDF8),
        surface: Color(0xFF151C28),
        onPrimary: Color(0xFF0B0F17),
        onSurface: Colors.white,
        outline: Color(0xFF233044),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0F17),
      cardTheme: const CardThemeData(
        color: Color(0xFF151C28),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0xFF233044)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      fontFamily: baseFont.fontFamily,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'INT Bank',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
