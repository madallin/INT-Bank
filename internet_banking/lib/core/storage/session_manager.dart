// lib/core/storage/session_manager.dart
// Session persistence using SharedPreferences

import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String keyUserId = 'loggedUserId';
  static const String keyPinVerified = 'pinVerified';

  static Future<void> saveUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyUserId, userId);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyUserId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserId);
    await prefs.remove(keyPinVerified);
  }

  static Future<void> setPinVerified(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPinVerified, value);
  }

  static Future<bool> isPinVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyPinVerified) ?? false;
  }

  static Future<void> saveLastPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPhone', phone);
  }

  static Future<String?> getLastPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastPhone');
  }
}
