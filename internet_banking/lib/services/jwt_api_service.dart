// lib/services/jwt_api_service.dart
// HTTP client wrapper care adaugă automat JWT access token
// Interceptează 401 (TOKEN_EXPIRED) și face refresh automat

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';
import '../core/storage/secure_session_manager.dart';

IOClient _createIOClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

class JwtApiService {
  static final JwtApiService _instance = JwtApiService._internal();
  factory JwtApiService() => _instance;
  JwtApiService._internal();

  /// Efectuează un request GET cu JWT. La 401 face refresh automat și reîncearcă.
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final client = _createIOClient();
    try {
      final accessToken = await SecureSessionManager.getAccessToken();
      final uri = Uri.parse('https://$serverUrl$path');

      final response = await client.get(uri, headers: {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      });

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh(client);
        if (refreshed) {
          final newToken = await SecureSessionManager.getAccessToken();
          return await client.get(uri, headers: {
            'Authorization': 'Bearer ${newToken ?? ''}',
            'Accept': 'application/json',
            if (headers != null) ...headers,
          });
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Efectuează un request POST cu JWT. La 401 face refresh automat și reîncearcă.
  Future<http.Response> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final client = _createIOClient();
    try {
      final accessToken = await SecureSessionManager.getAccessToken();
      final uri = Uri.parse('https://$serverUrl$path');

      final response = await client.post(uri, headers: {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      }, body: body != null ? jsonEncode(body) : null);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh(client);
        if (refreshed) {
          final newToken = await SecureSessionManager.getAccessToken();
          return await client.post(uri, headers: {
            'Authorization': 'Bearer ${newToken ?? ''}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (headers != null) ...headers,
          }, body: body != null ? jsonEncode(body) : null);
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Efectuează un request PUT cu JWT. La 401 face refresh automat și reîncearcă.
  Future<http.Response> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final client = _createIOClient();
    try {
      final accessToken = await SecureSessionManager.getAccessToken();
      final uri = Uri.parse('https://$serverUrl$path');

      final response = await client.put(uri, headers: {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      }, body: body != null ? jsonEncode(body) : null);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh(client);
        if (refreshed) {
          final newToken = await SecureSessionManager.getAccessToken();
          return await client.put(uri, headers: {
            'Authorization': 'Bearer ${newToken ?? ''}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (headers != null) ...headers,
          }, body: body != null ? jsonEncode(body) : null);
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Încearcă să reîmprospăteze tokenii folosind refreshToken
  Future<bool> _tryRefresh(IOClient client) async {
    try {
      final refreshToken = await SecureSessionManager.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await client.post(
        Uri.parse('https://$serverUrl/auth-session/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await SecureSessionManager.saveAccessToken(data['accessToken']);
        await SecureSessionManager.saveRefreshToken(data['refreshToken']);
        return true;
      }

      // Refresh eșuat — ștergem sesiunea
      await SecureSessionManager.clearAll();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Login JWT (se apelează după verificarea PIN)
  static Future<Map<String, dynamic>?> login(String phone, String pin) async {
    final client = _createIOClient();
    try {
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth-session/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await SecureSessionManager.saveAccessToken(data['accessToken']);
        await SecureSessionManager.saveRefreshToken(data['refreshToken']);
        await SecureSessionManager.saveUserId(data['userId']);
        return data;
      }

      return null;
    } catch (e) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Logout: șterge sesiunea de pe server și tokenii locali
  static Future<void> logout() async {
    final client = _createIOClient();
    try {
      final refreshToken = await SecureSessionManager.getRefreshToken();
      if (refreshToken != null) {
        await client.post(
          Uri.parse('https://$serverUrl/auth-session/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      }
    } catch (_) {
      // Ignorăm erori la logout
    } finally {
      client.close();
      await SecureSessionManager.clearAll();
    }
  }

  /// Încearcă să reîmprospăteze sesiunea la pornirea aplicației.
  /// Returnează userId dacă refresh-ul a reușit, null dacă sesiunea e expirată.
  static Future<int?> tryRefreshSession() async {
    final client = _createIOClient();
    try {
      final refreshToken = await SecureSessionManager.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final response = await client.post(
        Uri.parse('https://$serverUrl/auth-session/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await SecureSessionManager.saveAccessToken(data['accessToken']);
        await SecureSessionManager.saveRefreshToken(data['refreshToken']);
        return await SecureSessionManager.getUserId();
      }

      // Refresh eșuat
      await SecureSessionManager.clearAll();
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
