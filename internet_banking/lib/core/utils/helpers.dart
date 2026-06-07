// lib/core/utils/helpers.dart
// General-purpose helper functions

import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

/// Normalizes a string: removes diacritics, lowercases, trims.
String normalize(String s) {
  var x = s.toLowerCase().trim();
  x = x.replaceAll('ă', 'a').replaceAll('â', 'a').replaceAll('î', 'i');
  x = x.replaceAll('ș', 's').replaceAll('ş', 's');
  x = x.replaceAll('ț', 't').replaceAll('ţ', 't');
  x = x.replaceAll(RegExp(r'\s+'), ' ');
  return x;
}

/// Removes diacritics from a string (preserves case).
String removeDiacritics(String s) {
  const map = <String, String>{
    'ă': 'a', 'Ă': 'A', 'â': 'a', 'Â': 'A',
    'î': 'i', 'Î': 'I', 'ș': 's', 'Ș': 'S',
    'ş': 's', 'Ş': 'S', 'ț': 't', 'Ț': 'T',
    'ţ': 't', 'Ţ': 'T',
  };
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

/// Returns device ID for Android/iOS/other.
Future<String> getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'dev-device';
    }
  } catch (_) {
    // Fall through
  }
  return 'dev-device';
}

/// Formats a phone number for display (e.g., +40 712 345 678).
String formatPhoneDisplay(String phoneNumber) {
  String cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');
  String countryCode = '';
  String nationalNumber = cleaned;
  if (cleaned.length > 9 && cleaned.startsWith('40')) {
    countryCode = '40';
    nationalNumber = cleaned.substring(2);
  }
  String formatted = '';
  for (int i = 0; i < nationalNumber.length; i++) {
    if (i > 0 && i % 3 == 0) formatted += ' ';
    formatted += nationalNumber[i];
  }
  return countryCode.isEmpty ? formatted : '+$countryCode $formatted';
}

/// Formats an IBAN with spaces every 4 characters.
String formatIBAN(String input) {
  String clean = input.replaceAll(' ', '').toUpperCase();
  String formatted = '';
  for (int i = 0; i < clean.length; i++) {
    if (i > 0 && i % 4 == 0) formatted += ' ';
    formatted += clean[i];
  }
  return formatted;
}

/// Formats a numeric amount with thousands separator (dot).
String formatAmount(String input) {
  String clean = input.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.isEmpty) return '';
  String reversed = clean.split('').reversed.join('');
  String formatted = '';
  for (int i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) formatted += '.';
    formatted += reversed[i];
  }
  return formatted.split('').reversed.join('');
}

/// Converts country code to emoji flag.
String countryCodeToEmoji(String countryCode) {
  final base = 0x1F1E6;
  final firstChar = countryCode.codeUnitAt(0) - 65 + base;
  final secondChar = countryCode.codeUnitAt(1) - 65 + base;
  return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
}

/// Truncates a string and adds ellipsis if too long.
String truncate(String s, int maxLength) {
  if (s.length <= maxLength) return s;
  return '${s.substring(0, maxLength)}...';
}
