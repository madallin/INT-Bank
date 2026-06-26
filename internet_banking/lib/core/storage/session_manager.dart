import 'package:shared_preferences/shared_preferences.dart';

class SessionManager
{
  static const _userIdKey = 'loggedUserId';

  static Future<void> saveUserId(int userId) async
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<int?> getUserId() async
  {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> clearUserId() async
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }
}
