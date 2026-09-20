import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/network/ssl_pinning_service.dart';

String hexToBase64(String hex) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return base64.encode(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String primaryHex =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const String backupHex =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const String mitmHex =
      '3333333333333333333333333333333333333333333333333333333333333333';

  final DateTime validTime = DateTime.utc(2026, 1, 1);
  final DateTime expiration = DateTime.utc(2027, 1, 1);
  final DateTime afterExpiration = DateTime.utc(2027, 6, 1);

  SslPinConfig config({
    String host = 'api.example-bank.com',
    List<String> pins = const <String>[primaryHex],
    bool enforcePinning = true,
    DateTime? pinExpirationDate,
  }) =>
      SslPinConfig(
        host: host,
        allowedSha256Pins: pins,
        enforcePinning: enforcePinning,
        pinExpirationDate: pinExpirationDate ?? expiration,
      );

  group('Valid pin matching', () {
    test('accepts a registered primary pin', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
      expect(result.errorMessage, isNull);
      expect(result.certificateFingerprint, primaryHex);
    });

    test('matches hex pins case-insensitively and with surrounding whitespace', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: '  API.Example-Bank.com  ',
        candidateFingerprint: '  ${primaryHex.toUpperCase()}  ',
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });

    test('matches a base64 candidate against a registered hex pin', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: hexToBase64(primaryHex),
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });

    test('matches a hex candidate against a registered base64 pin', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config(pins: <String>[hexToBase64(primaryHex)]));

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex.toUpperCase(),
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });
  });

  group('Unrecognized fingerprint rejection (MITM)', () {
    test('rejects an unknown MITM fingerprint', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: mitmHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.pinMismatchRejected);
      expect(result.errorMessage, isNotNull);
      expect(result.certificateFingerprint, mitmHex);
    });

    test('rejects an unregistered host', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'rogue.example.com',
        candidateFingerprint: primaryHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.hostNotConfigured);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('Backup pin rotation', () {
    test('succeeds when the candidate matches the secondary backup pin', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(
        config(pins: <String>[primaryHex, backupHex]),
      );

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: backupHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });

    test('still succeeds on the primary pin when a backup pin is present', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(
        config(pins: <String>[primaryHex, backupHex]),
      );

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });
  });

  group('Pin expiration', () {
    test('rejects pins when the current time is after the expiration date', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: afterExpiration,
      );

      expect(result.status, SslVerificationStatus.expiredPins);
      expect(result.errorMessage, isNotNull);
    });

    test('treats the exact expiration instant as still valid', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: expiration,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
    });
  });

  group('Bypass attempt detection', () {
    test('rejects when enforcePinning is disabled', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config(enforcePinning: false));

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.bypassAttemptDetected);
      expect(result.errorMessage, isNotNull);
    });

    test('rejects a blank candidate fingerprint', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: '   ',
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.bypassAttemptDetected);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('isConnectionPermitted consistency', () {
    test('is permitted only when the verification status is validPinMatch', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config(pins: <String>[primaryHex, backupHex]));
      service.registerHostPin(
        config(
          host: 'disabled.example-bank.com',
          enforcePinning: false,
        ),
      );

      bool permittedFor(String host, String fingerprint, DateTime time) =>
          service.isConnectionPermitted(
            host: host,
            candidateFingerprint: fingerprint,
            currentTime: time,
          );

      expect(
        permittedFor('api.example-bank.com', primaryHex, validTime),
        isTrue,
      );
      expect(
        permittedFor('api.example-bank.com', backupHex, validTime),
        isTrue,
      );
      expect(
        permittedFor('api.example-bank.com', mitmHex, validTime),
        isFalse,
      );
      expect(
        permittedFor('api.example-bank.com', primaryHex, afterExpiration),
        isFalse,
      );
      expect(
        permittedFor('unknown.example-bank.com', primaryHex, validTime),
        isFalse,
      );
      expect(
        permittedFor('disabled.example-bank.com', primaryHex, validTime),
        isFalse,
      );
      expect(
        permittedFor('api.example-bank.com', '', validTime),
        isFalse,
      );
    });
  });

  group('Security alert emission', () {
    test('emits a pinMismatchRejected alert for a MITM fingerprint', () {
      final List<SslSecurityAlert> alerts = <SslSecurityAlert>[];
      final SslPinningService service = SslPinningService(
        alertSink: alerts.add,
      );
      service.registerHostPin(config());

      service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: mitmHex,
        currentTime: validTime,
      );

      expect(alerts, hasLength(1));
      final SslSecurityAlert alert = alerts.single;
      expect(alert.host, 'api.example-bank.com');
      expect(alert.candidateFingerprint, mitmHex);
      expect(alert.status, SslVerificationStatus.pinMismatchRejected);
      expect(alert.timestamp, validTime);
    });

    test('emits an expiredPins alert after the expiration date', () {
      final List<SslSecurityAlert> alerts = <SslSecurityAlert>[];
      final SslPinningService service = SslPinningService(
        alertSink: alerts.add,
      );
      service.registerHostPin(config());

      service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: afterExpiration,
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.status, SslVerificationStatus.expiredPins);
      expect(alerts.single.timestamp, afterExpiration);
    });

    test('emits a bypassAttemptDetected alert for a blank fingerprint', () {
      final List<SslSecurityAlert> alerts = <SslSecurityAlert>[];
      final SslPinningService service = SslPinningService(
        alertSink: alerts.add,
      );
      service.registerHostPin(config());

      service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: '   ',
        currentTime: validTime,
      );

      expect(alerts, hasLength(1));
      expect(
        alerts.single.status,
        SslVerificationStatus.bypassAttemptDetected,
      );
    });

    test('emits a bypassAttemptDetected alert when enforcement is disabled', () {
      final List<SslSecurityAlert> alerts = <SslSecurityAlert>[];
      final SslPinningService service = SslPinningService(
        alertSink: alerts.add,
      );
      service.registerHostPin(config(enforcePinning: false));

      service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: primaryHex,
        currentTime: validTime,
      );

      expect(alerts, hasLength(1));
      expect(
        alerts.single.status,
        SslVerificationStatus.bypassAttemptDetected,
      );
    });

    test('does not emit an alert for a valid pin match', () {
      final List<SslSecurityAlert> alerts = <SslSecurityAlert>[];
      final SslPinningService service = SslPinningService(
        alertSink: alerts.add,
      );
      service.registerHostPin(config(pins: <String>[primaryHex, backupHex]));

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: backupHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.validPinMatch);
      expect(alerts, isEmpty);
    });

    test('supports construction without an alert sink', () {
      final SslPinningService service = SslPinningService();
      service.registerHostPin(config());

      final SslVerificationResult result = service.verifyCertificateFingerprint(
        host: 'api.example-bank.com',
        candidateFingerprint: mitmHex,
        currentTime: validTime,
      );

      expect(result.status, SslVerificationStatus.pinMismatchRejected);
    });
  });
}
