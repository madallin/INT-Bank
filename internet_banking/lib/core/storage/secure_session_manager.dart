import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionManager
{
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _userIdKey = 'userId';
  static const _phoneKey = 'phone';

  static Future<void> saveAccessToken(String token) async =>
      await _storage.write(key: _accessTokenKey, value: token);

  static Future<String?> getAccessToken() async =>
      await _storage.read(key: _accessTokenKey);

  static Future<void> saveRefreshToken(String token) async =>
      await _storage.write(key: _refreshTokenKey, value: token);

  static Future<String?> getRefreshToken() async =>
      await _storage.read(key: _refreshTokenKey);

  static Future<void> saveUserId(int userId) async =>
      await _storage.write(key: _userIdKey, value: userId.toString());

  static Future<int?> getUserId() async
  {
    final val = await _storage.read(key: _userIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<void> savePhone(String phone) async =>
      await _storage.write(key: _phoneKey, value: phone);

  static Future<String?> getPhone() async =>
      await _storage.read(key: _phoneKey);

  static Future<void> clearAll() async =>
      await _storage.deleteAll();

  static Future<void> clearSession() async
  {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _phoneKey);
  }
}
