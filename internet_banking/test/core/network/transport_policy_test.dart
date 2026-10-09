import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/network/transport_security.dart';
import 'package:internet_banking/core/utils/app_log.dart';
import 'package:internet_banking/core/utils/error_messages.dart';
import 'package:internet_banking/features/error/misconfigured_app.dart';

import '../../support/test_app.dart';

/// A release build may never talk to the bank without certificate pins, and never logs.
void main() {
  setUpAll(setUpTestApp);
  tearDown(() {
    TransportPolicy.requirePins = false;
    dotenv.testLoad(fileInput: '');
  });

  group('Transport policy', () {
    test('debug builds without pins use ordinary certificate checks', () {
      dotenv.testLoad(fileInput: 'CERT_SHA256_PINS=');
      TransportPolicy.requirePins = false;
      expect(TransportPolicy.mode, TransportSecurity.systemTrust);
    });

    test('a release build without pins is misconfigured, with pins it is pinned', () {
      TransportPolicy.requirePins = true;
      dotenv.testLoad(fileInput: 'CERT_SHA256_PINS=');
      expect(TransportPolicy.mode, TransportSecurity.misconfigured);

      dotenv.testLoad(fileInput: 'CERT_SHA256_PINS=${'ab' * 32}');
      expect(TransportPolicy.mode, TransportSecurity.pinned);
    });

    test('when misconfigured, API requests fail before anything is sent', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://bank.example'))..httpClientAdapter = RefusingHttpClientAdapter();

      final error = await dio.post('/auth-session/login', data: {'pin': '123456'}).then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<DioException>().having((e) => e.type, 'type', DioExceptionType.badCertificate));
      expect(friendlyErrorMessage(error!), isNot(contains('pins')), reason: 'the customer sees a plain message');
    });

    testWidgets('a misconfigured release build explains instead of starting', (tester) async {
      await tester.pumpWidget(const MisconfiguredApp());
      await tester.pump();

      expect(find.text("The app isn't set up"), findsOneWidget, reason: 'the test device language is English');
    });
  });

  group('AppLog', () {
    test('prints nothing when disabled, as in release builds', () {
      final lines = <String>[];
      final previousSink = AppLog.sink;
      final previousEnabled = AppLog.enabled;
      addTearDown(() {
        AppLog.sink = previousSink;
        AppLog.enabled = previousEnabled;
      });
      AppLog.sink = lines.add;

      AppLog.enabled = true;
      AppLog.debug('Error fetching cards', 'boom');
      AppLog.enabled = false;
      AppLog.debug('Error fetching cards', 'secret');

      expect(lines, ['Error fetching cards: boom']);
    });
  });
}
