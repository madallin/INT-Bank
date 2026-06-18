// lib/core/storage/secure_session_manager.dart
// JWT tokens stocate in Keychain/Keystore (flutter_secure_storage)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionManager {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessToken = 'jwt_access_token';
  static const _keyRefreshToken = 'jwt_refresh_token';
  static const _keyUserId = 'jwt_user_id';
  static const _keyPhone = 'jwt_user_phone';

  // --- Access Token ---
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  // --- Refresh Token ---
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // --- User ID ---
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: _keyUserId, value: userId.toString());
  }

  static Future<int?> getUserId() async {
    final val = await _storage.read(key: _keyUserId);
    return val != null ? int.tryParse(val) : null;
  }

  // --- Phone Number ---
  static Future<void> savePhone(String phone) async {
    await _storage.write(key: _keyPhone, value: phone);
  }

  static Future<String?> getPhone() async {
    return await _storage.read(key: _keyPhone);
  }

  // --- Clear all (logout) ---
  static Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyPhone);
  }

  /// Verifică dacă există o sesiune JWT activă (refresh token salvat)
  static Future<bool> hasSession() async {
    final refreshToken = await getRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
  }
}
