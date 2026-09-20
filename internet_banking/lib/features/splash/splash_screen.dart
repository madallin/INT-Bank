import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../services/jwt_api_service.dart';
import '../welcome/welcome_screen.dart';
import '../auth/screens/pin_screen.dart';
import '../error/screens/error_screen.dart';

class SplashScreen extends StatefulWidget
{
  const SplashScreen({super.key});

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
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      return response.statusCode == 200;
    }
    catch (e)
    {
      debugPrint('Server connection error: $e');
      return false;
    }
  }

  Future<void> _checkSessionAndNavigate() async
  {
    await Future.delayed(const Duration(seconds: 4));
    if(!mounted) return;

    final serverAvailable = await _checkServerConnection();
    if(!mounted) return;

    if(!serverAvailable)
{
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            errorMessage:
                'Nu s-a putut realiza conexiunea cu serverul. Așteptăm conexiunea...',
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

    final userId = await JwtApiService.tryRefreshSession();
    if(!mounted) return;

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

