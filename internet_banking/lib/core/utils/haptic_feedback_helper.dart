import 'package:flutter/services.dart';

/// Centralized utility for consistent tactile vibrations and physical reassurance across the banking app.
class HapticFeedbackHelper {
  HapticFeedbackHelper._();

  /// Subtle tactile response for normal button and keypad taps.
  static Future<void> buttonTap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Click feedback when cycling tabs, switches, or selecting options.
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Firm tactile pulse when flipping credit card or opening security drawer.
  static Future<void> cardFlip() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Reassuring double or medium pulse upon payment, FX, or transfer success.
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy warning pulse for validation failure or failed authorization.
  static Future<void> error() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
