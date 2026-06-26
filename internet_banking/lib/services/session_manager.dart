import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager
{
  static const _storage = FlutterSecureStorage();

  static const _keyUserId = 'loggedUserIdKey';
  static const _keyToken = 'authToken';

  static Future<void> saveUserId(int userId) async =>
      await _storage.write(key: _keyUserId, value: userId.toString());

  static Future<int?> getUserId() async
  {
    final val = await _storage.read(key: _keyUserId);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<void> clearUserId() async =>
      await _storage.delete(key: _keyUserId);

  static Future<void> saveToken(String token) async =>
      await _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() async =>
      await _storage.read(key: _keyToken);

  static Future<void> clearToken() async =>
      await _storage.delete(key: _keyToken);

  static Future<void> clearAll() async =>
      await _storage.deleteAll();
}
