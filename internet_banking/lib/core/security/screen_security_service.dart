import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/app_log.dart';

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
      AppLog.debug('Screen security not supported or failed', e);
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
      AppLog.debug('Disable screen security failed', e);
    }
  }
}
