import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import 'push_notification_service.dart';

class PushNotificationListener {
  static final PushNotificationListener _instance = PushNotificationListener._internal();
  factory PushNotificationListener() => _instance;
  PushNotificationListener._internal();

  HttpClient? _httpClient;
  StreamSubscription? _subscription;
  bool _active = false;
  int? _currentUserId;
  VoidCallback? _onNotificationReceived;

  void start(int userId, {VoidCallback? onNotificationReceived}) {
    if (_active && _currentUserId == userId) return;
    stop();

    _active = true;
    _currentUserId = userId;
    _onNotificationReceived = onNotificationReceived;

    _connectStream();
  }

  void stop() {
    _active = false;
    _currentUserId = null;
    _onNotificationReceived = null;
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Future<void> _connectStream() async {
    if (!_active || _currentUserId == null) return;

    try {
      _httpClient?.close(force: true);
      _httpClient = HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 15);

      final uri = Uri.parse('${AppConfig.baseUrl}/users/$_currentUserId/notifications/stream');
      debugPrint('[PushNotificationListener] Connecting to SSE stream: $uri');

      final request = await _httpClient!.getUrl(uri);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      final response = await request.close();

      if (response.statusCode == 200) {
        debugPrint('[PushNotificationListener] Push notification stream established');

        _subscription = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleLine,
              onError: (error) {
                debugPrint('[PushNotificationListener] Stream error: $error');
                _scheduleReconnect();
              },
              onDone: () {
                debugPrint('[PushNotificationListener] Stream completed');
                _scheduleReconnect();
              },
              cancelOnError: true,
            );
      } else {
        debugPrint('[PushNotificationListener] Failed to connect: ${response.statusCode}');
        _scheduleReconnect();
      }
    } catch (e) {
      debugPrint('[PushNotificationListener] Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty || line.startsWith(':')) return; // keep-alive ping or comment

    if (line.startsWith('data:')) {
      final jsonStr = line.substring(5).trim();
      if (jsonStr.isEmpty) return;

      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final title = data['title'] as String? ?? 'INTBank Notificare';
        final message = data['message'] as String? ?? '';
        final type = data['type'] as String? ?? 'TRANSFER_RECEIVED';
        final id = data['id'] as int?;

        debugPrint('[PushNotificationListener] PUSH EVENT RECEIVED: $type - $title');

        PushNotificationService().showPushNotification(
          id: id,
          title: title,
          body: message,
          type: type,
          payload: jsonEncode(data),
        );

        if (_onNotificationReceived != null) {
          _onNotificationReceived!();
        }
      } catch (e) {
        debugPrint('[PushNotificationListener] Error parsing push event data: $e');
      }
    }
  }

  void _scheduleReconnect() {
    if (!_active) return;
    _subscription?.cancel();
    _subscription = null;
    Timer(const Duration(seconds: 5), () {
      if (_active) {
        debugPrint('[PushNotificationListener] Reconnecting to push stream...');
        _connectStream();
      }
    });
  }
}
