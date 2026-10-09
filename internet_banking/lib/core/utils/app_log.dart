import 'package:flutter/foundation.dart';

/// The app's only logger. In debug builds it prints [message] and, if given, the
/// error; in profile and release builds it prints nothing, because `debugPrint` is
/// not removed from release builds and anything printed ends up in the system log,
/// readable by other tools on the device (amounts, IBANs, server replies).
abstract final class AppLog
{
  /// Whether anything is printed. Tests may switch it to check release behaviour.
  @visibleForTesting
  static bool enabled = kDebugMode;

  /// Where output goes; tests replace it to see what would be printed.
  @visibleForTesting
  static void Function(String line) sink = debugPrint;

  static void debug(String message, [Object? error])
  {
    if(!enabled) return;
    sink(error == null ? message : '$message: $error');
  }
}
