import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences the customer picks on the Profile tab: theme, language and how soon the
/// app locks itself. Stored on this device only; nothing here is sensitive.
class AppSettings extends ChangeNotifier
{
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _themeKey = 'settings.themeMode';
  static const _languageKey = 'settings.language';
  static const _autoLockKey = 'settings.autoLockMinutes';

  /// Auto-lock choices, in minutes. Longer would leave an unattended banking app open.
  static const autoLockChoices = [1, 2, 5];
  static const defaultAutoLockMinutes = 5;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  int _autoLockMinutes = defaultAutoLockMinutes;

  ThemeMode get themeMode => _themeMode;

  /// The chosen language, or null to follow the phone.
  Locale? get locale => _locale;

  int get autoLockMinutes => _autoLockMinutes;
  Duration get autoLock => Duration(minutes: _autoLockMinutes);

  Future<void> load() async
  {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == prefs.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    final language = prefs.getString(_languageKey);
    _locale = language == 'ro' || language == 'en' ? Locale(language!) : null;
    final minutes = prefs.getInt(_autoLockKey);
    _autoLockMinutes = autoLockChoices.contains(minutes) ? minutes! : defaultAutoLockMinutes;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async
  {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// [locale] null follows the phone's language.
  Future<void> setLocale(Locale? locale) async
  {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if(locale == null)
    {
      await prefs.remove(_languageKey);
    }
    else
    {
      await prefs.setString(_languageKey, locale.languageCode);
    }
  }

  Future<void> setAutoLockMinutes(int minutes) async
  {
    if(!autoLockChoices.contains(minutes)) return;
    _autoLockMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, minutes);
  }

  @visibleForTesting
  void debugReset()
  {
    _themeMode = ThemeMode.system;
    _locale = null;
    _autoLockMinutes = defaultAutoLockMinutes;
    notifyListeners();
  }
}
