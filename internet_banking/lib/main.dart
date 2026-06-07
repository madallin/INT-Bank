// lib/main.dart
// Application entry point

import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data/models/location_data.dart';
import 'config/app_config.dart';
import 'core/storage/session_manager.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/screens/pin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await init();
  await loadJudete();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      final userId = await SessionManager.getUserId();
      if (userId != null) {
        await SessionManager.setPinVerified(false);

        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PinScreen(userId: userId, set: false),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INT Bank',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(lightForestGreenColor),
          primary: const Color(lightForestGreenColor),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
