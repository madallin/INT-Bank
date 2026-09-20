import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyModeService {
  static final PrivacyModeService _instance = PrivacyModeService._internal();
  factory PrivacyModeService() => _instance;
  PrivacyModeService._internal();

  static const String _prefKey = 'privacy_mode_enabled';

  final ValueNotifier<bool> isPrivacyModeEnabled = ValueNotifier<bool>(false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isPrivacyModeEnabled.value = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> togglePrivacyMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !isPrivacyModeEnabled.value;
    isPrivacyModeEnabled.value = newValue;
    await prefs.setBool(_prefKey, newValue);
  }

  Future<void> setPrivacyMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    isPrivacyModeEnabled.value = enabled;
    await prefs.setBool(_prefKey, enabled);
  }

  String formatOrMask(String value, {String? mask}) {
    if (!isPrivacyModeEnabled.value) {
      return value;
    }
    if (mask != null) {
      return mask;
    }
    // Default masked format replacing numeric digits while keeping currency
    final parts = value.trim().split(' ');
    if (parts.length > 1) {
      return '\u2022\u2022\u2022\u2022 ' + parts.sublist(1).join(' ');
    }
    return '\u2022\u2022\u2022\u2022';
  }
}
