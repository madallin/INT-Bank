import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager
{
  static const _storage = FlutterSecureStorage();
  static const _key = 'loggedUserId';

  static Future<void> saveUserId(int userId) async
  {
    await _storage.write(key: _key, value: userId.toString());
  }

  static Future<int?> getUserId() async
  {
    final val = await _storage.read(key: _key);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<void> clearUserId() async
  {
    await _storage.delete(key: _key);
  }
}
