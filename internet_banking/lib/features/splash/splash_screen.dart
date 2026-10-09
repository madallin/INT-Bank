import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../services/jwt_api_service.dart';
import '../welcome/welcome_screen.dart';
import '../auth/screens/pin_screen.dart';
import '../error/screens/error_screen.dart';
import '../../l10n/l10n.dart';

class SplashScreen extends StatefulWidget
{
  const SplashScreen({super.key});

  /// The logo stays up at least this long, so a fast start does not flash.
  static const minimumShown = Duration(milliseconds: 600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
{
  @override
  void initState()
  {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<bool> _checkServerConnection() async
  {
    try
    {
      final response = await DioClient().get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    }
    catch (_)
    {
      return false;
    }
  }

  Future<void> _checkSessionAndNavigate() async
  {
    // The checks run while the logo shows; the splash lasts only as long as they need.
    final minimum = Future<void>.delayed(SplashScreen.minimumShown);
    final serverAvailable = await _checkServerConnection();
    final userId = serverAvailable ? await JwtApiService.tryRefreshSession() : null;
    await minimum;
    if(!mounted) return;

    if(!serverAvailable)
{
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            errorMessage:
                context.l10n.splashSPututRealizaConexiunea,
            onConnectionRestored: (context)
            {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
          ),
        ),
        (route) => false,
      );
      return;
    }

    if(userId != null)
{
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PinScreen(userId: userId, set: false, popOnSuccess: false, useJwtLogin: true),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: const Color(0xFF00695C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/foreground.png', width: 200),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

