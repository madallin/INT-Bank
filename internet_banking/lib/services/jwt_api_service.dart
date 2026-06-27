import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../core/storage/secure_session_manager.dart';
import '../data/models/auth_response.dart';

class JwtApiService
{
  static final DioClient _client = DioClient();

  static Future<AuthResponse?> login(String phone, String pin) async
  {
    try
    {
      final response = await _client.post(
        '/auth-session/login',
        data: {'phone': phone, 'pin': pin},
      );

      if(response.statusCode == 200)
      {
        final data = response.data as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);

        if(authResponse.accessToken.isNotEmpty && authResponse.refreshToken.isNotEmpty)
        {
          await SecureSessionManager.saveAccessToken(authResponse.accessToken);
          await SecureSessionManager.saveRefreshToken(authResponse.refreshToken);
          if(authResponse.userId != null)
          {
            await SecureSessionManager.saveUserId(authResponse.userId!);
          }
        }
        return authResponse;
      }
      return null;
    }
    on DioException
    {
      return null;
    }
  }

  static Future<void> logout() async
  {
    try
    {
      final accessToken = await SecureSessionManager.getAccessToken();
      if(accessToken != null)
      {
        await _client.post(
          '/auth-session/logout',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      }
    }
    catch(_)
    {
      // best-effort server notification
    }
    await SecureSessionManager.clearSession();
  }

  static Future<int?> tryRefreshSession() async
  {
    try
    {
      final refreshToken = await SecureSessionManager.getRefreshToken();
      if(refreshToken == null) return null;

      final response = await _client.post(
        '/auth-session/refresh',
        data: {'refreshToken': refreshToken},
      );

      if(response.statusCode == 200)
      {
        final data = response.data as Map<String, dynamic>;
        final refreshResponse = TokenRefreshResponse.fromJson(data);

        await SecureSessionManager.saveAccessToken(refreshResponse.accessToken);

        if(refreshResponse.userId != null)
        {
          await SecureSessionManager.saveUserId(refreshResponse.userId!);
          return refreshResponse.userId;
        }
      }
      return null;
    }
    on DioException
    {
      return null;
    }
  }
}
