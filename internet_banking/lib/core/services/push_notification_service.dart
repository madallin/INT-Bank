import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'intbank_transfers';
  static const String channelName = 'Tranzactii & Securitate';
  static const String channelDescription = 'Notificari push pentru transferuri de bani si alerte de securitate INTBank';

  Function(String? payload)? onNotificationTapped;

  Future<void> init({Function(String? payload)? onNotificationClick}) async {
    if (_isInitialized) return;
    onNotificationTapped = onNotificationClick;

    // Android Initialization Settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization Settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onNotificationTapped != null) {
          onNotificationTapped!(response.payload);
        }
      },
    );

    // Create high-importance Android Notification Channel
    if (Platform.isAndroid) {
      final androidNotificationChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 150, 250]),
        playSound: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidNotificationChannel);
    }

    _isInitialized = true;
    debugPrint('[PushNotificationService] Initialized native push notification channels');
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> showPushNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    String? type,
  }) async {
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'INTBank • $title',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00695C), // INTBank forest green
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 150, 250]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'INTBank Mobile',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );

    debugPrint('[PushNotificationService] Native push notification displayed: $title');
  }
}
