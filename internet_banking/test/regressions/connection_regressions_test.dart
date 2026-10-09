import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/config/app_config.dart';
import 'package:internet_banking/core/services/push_notification_listener.dart';

/// Guards for bugs that once kept the app from talking to the real server.
void main() {
  test('release builds may use the network (INTERNET is in the main manifest)', () {
    // Flutter adds INTERNET only to the debug and profile manifests; without it here a
    // release APK cannot reach the bank at all.
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('the approval socket points at the handler, on the API port', () {
    // It used to be wss://<host>, which never reached /ws/approval.
    expect(AppConfig.wsUrl, 'wss://localhost:8443/ws/approval');
  });

  test('the notification stream sends the session token', () async {
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'session-token'});
    final recorder = _RecordingHttpOverrides();
    await HttpOverrides.runZoned(() async {
      PushNotificationListener().start(7);
      await recorder.requested.future.timeout(const Duration(seconds: 5));
      PushNotificationListener().stop();
    }, createHttpClient: recorder.create);

    expect(recorder.path, '/users/7/notifications/stream');
    expect(recorder.authorization, 'Bearer session-token');
  });
}

/// Captures the stream request instead of opening a connection.
class _RecordingHttpOverrides {
  final requested = Completer<void>();
  String? path;
  String? authorization;

  HttpClient create(SecurityContext? context) => _RecordingClient(this);
}

class _RecordingClient implements HttpClient {
  _RecordingClient(this.recorder);

  final _RecordingHttpOverrides recorder;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _RecordingRequest(recorder, url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _RecordingRequest implements HttpClientRequest {
  _RecordingRequest(this.recorder, this.url);

  final _RecordingHttpOverrides recorder;
  final Uri url;
  final _Headers _headers = _Headers();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async {
    recorder.path = url.path;
    recorder.authorization = _headers.values['authorization'];
    if (!recorder.requested.isCompleted) recorder.requested.complete();
    throw const SocketException('recorded (test)');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _Headers implements HttpHeaders {
  final Map<String, String> values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => values[name.toLowerCase()] = '$value';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}
