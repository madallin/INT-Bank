import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Banking screen defense against screen recorders, mirroring, and multitasking snapshots.
class ScreenSecurityService
{
  static final ScreenSecurityService instance = ScreenSecurityService._();
  ScreenSecurityService._();

  static const MethodChannel _channel = MethodChannel('com.intbank.security/screen');

  /// Enables screen protection (e.g. FLAG_SECURE on Android, blur overlay on iOS).
  Future<void> enableSecureScreen() async
  {
    if (kIsWeb) return;
    try
    {
      await _channel.invokeMethod('enableSecureScreen');
    }
    catch (e)
    {
      debugPrint('Screen security not supported or failed: ');
    }
  }

  /// Disables screen protection.
  Future<void> disableSecureScreen() async
  {
    if (kIsWeb) return;
    try
    {
      await _channel.invokeMethod('disableSecureScreen');
    }
    catch (e)
    {
      debugPrint('Disable screen security failed: ');
    }
  }
}
