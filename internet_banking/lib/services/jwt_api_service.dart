import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';
import '../core/storage/secure_session_manager.dart';

class JwtApiService
{
  static http.Client _createHttpClient()
  {
    final ioc = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  static Future<Map<String, dynamic>?> login(String phone, String pin) async
  {
    final client = _createHttpClient();
    try
    {
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth-session/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'pin': pin}),
      );

      if(response.statusCode == 200)
      {
        final data = jsonDecode(response.body);
        if(data['accessToken'] != null && data['refreshToken'] != null)
        {
          await SecureSessionManager.saveAccessToken(data['accessToken']);
          await SecureSessionManager.saveRefreshToken(data['refreshToken']);
          if(data['userId'] != null)
          {
            await SecureSessionManager.saveUserId(data['userId']);
          }
        }
        return data;
      }
      return null;
    }
    catch(e)
    {
      return null;
    }
    finally
    {
      client.close();
    }
  }

  static Future<void> logout() async
  {
    final client = _createHttpClient();
    try
    {
      final accessToken = await SecureSessionManager.getAccessToken();
      if(accessToken != null)
      {
        await client.post(
          Uri.parse('https://$serverUrl/auth-session/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );
      }
    }
    finally
    {
      client.close();
    }
    await SecureSessionManager.clearSession();
  }

  static Future<int?> tryRefreshSession() async
  {
    final client = _createHttpClient();
    try
    {
      final refreshToken = await SecureSessionManager.getRefreshToken();
      if(refreshToken == null) return null;

      final response = await client.post(
        Uri.parse('https://$serverUrl/auth-session/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if(response.statusCode == 200)
      {
        final data = jsonDecode(response.body);
        if(data['accessToken'] != null)
        {
          await SecureSessionManager.saveAccessToken(data['accessToken']);
        }
        if(data['userId'] != null)
        {
          final userId = data['userId'] is int
              ? data['userId']
              : int.tryParse(data['userId'].toString());
          if(userId != null)
          {
            await SecureSessionManager.saveUserId(userId);
          }
          return userId;
        }
      }
      return null;
    }
    catch(e)
    {
      return null;
    }
    finally
    {
      client.close();
    }
  }
}
