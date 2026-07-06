import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../config/app_config.dart';
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

  http.Client _createHttpClient()
  {
    return IOClient(HttpClient());
  }

  Future<bool> _checkServerConnection() async
  {
    final client = _createHttpClient();
    try
    {
      final uri = Uri.parse('${AppConfig.baseUrl}/health');
      final response = await client.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Timeout'),
      );
      return response.statusCode == 200;
    }
    catch (e)
{
      debugPrint('Server connection error: $e');
      return false;
    }
    finally
    {
      client.close();
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

