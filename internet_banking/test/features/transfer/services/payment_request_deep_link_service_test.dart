import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/services/payment_request_deep_link_service.dart';

const String testSecret = 'unit-test-secret-key';

final DateTime fixedNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
final DateTime futureExpiry = DateTime.utc(2026, 12, 31, 23, 59, 59);
final DateTime pastExpiry = DateTime.utc(2025, 1, 1, 0, 0, 0);

PaymentRequestData buildData({
  String recipientId = 'recipient-001',
  String recipientName = 'Ana Popescu',
  String iban = 'RO49AAAA1B31007593840000',
  double amount = 250.75,
  String currency = 'RON',
  String description = 'Dinner split',
  DateTime? expiresAt,
}) {
  return PaymentRequestData(
    recipientId: recipientId,
    recipientName: recipientName,
    iban: iban,
    amount: amount,
    currency: currency,
    description: description,
    expiresAt: expiresAt ?? futureExpiry,
  );
}

Map<String, String> withOverride(
  Uri uri,
  String key,
  String value,
) {
  final Map<String, String> parameters =
      Map<String, String>.from(uri.queryParameters);
  parameters[key] = value;
  return parameters;
}

void main() {
  final PaymentRequestDeepLinkService service =
      PaymentRequestDeepLinkService();

  group('crypto known answers', () {
    test('SHA-256 of abc matches the known digest', () {
      expect(
        PaymentRequestDeepLinkService.debugSha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('SHA-256 of empty string matches the known digest', () {
      expect(
        PaymentRequestDeepLinkService.debugSha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('HMAC-SHA256 matches RFC 4231 test case 2', () {
      final String key = String.fromCharCodes(List<int>.filled(20, 0x0B));
      expect(
        PaymentRequestDeepLinkService.debugHmacSha256Hex(key, 'Hi There'),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });
  });

  group('canonical query string', () {
    test('emits parameters in the documented fixed order', () {
      final PaymentRequestData data = buildData(description: 'a b');
      final String canonical = service.buildCanonicalQueryString(data);
      expect(
        canonical,
        'amount=250.75'
        '&currency=RON'
        '&description=a%20b'
        '&expiresAt=2026-12-31T23%3A59%3A59.000Z'
        '&iban=RO49AAAA1B31007593840000'
        '&recipientId=recipient-001'
        '&recipientName=Ana%20Popescu',
      );
    });

    test('never includes the signature parameter', () {
      final PaymentRequestData data =
          buildData().copyWith(signature: 'deadbeef');
      expect(service.buildCanonicalQueryString(data).contains('signature'),
          isFalse);
    });

    test('treats an empty description as an empty canonical value', () {
      final PaymentRequestData data = buildData(description: '');
      expect(
        service.buildCanonicalQueryString(data).contains('&description=&'),
        isTrue,
      );
    });
  });

  group('signature', () {
    test('is deterministic for identical input', () {
      final PaymentRequestData data = buildData();
      final String first = service.computeSignature(data, secretKey: testSecret);
      final String second =
          service.computeSignature(data, secretKey: testSecret);
      expect(first, second);
    });

    test('is lower-case hexadecimal with the expected length', () {
      final String signature =
          service.computeSignature(buildData(), secretKey: testSecret);
      expect(signature.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(signature), isTrue);
    });

    test('changes when the secret changes', () {
      final PaymentRequestData data = buildData();
      final String first = service.computeSignature(data, secretKey: 'a');
      final String second = service.computeSignature(data, secretKey: 'b');
      expect(first, isNot(second));
    });
  });

  group('deep link round trip', () {
    test('generates an intbank://pay link', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      expect(uri.scheme, PaymentRequestDeepLinkService.deepLinkScheme);
      expect(uri.host, 'pay');
    });

    test('parses and validates a freshly generated link', () {
      final PaymentRequestData data = buildData();
      final Uri uri = service.generateDeepLink(data, secretKey: testSecret);
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.valid);
      expect(result.isValid, isTrue);
      final PaymentRequestData parsed = result.data!;
      expect(parsed.recipientId, data.recipientId);
      expect(parsed.recipientName, data.recipientName);
      expect(parsed.iban, data.iban);
      expect(parsed.amount, data.amount);
      expect(parsed.currency, data.currency);
      expect(parsed.description, data.description);
      expect(parsed.expiresAt.toUtc(), data.expiresAt.toUtc());
      expect(parsed.signature, service.computeSignature(data, secretKey: testSecret));
    });

    test('round trips an empty description', () {
      final PaymentRequestData data = buildData(description: '');
      final Uri uri = service.generateDeepLink(data, secretKey: testSecret);
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.valid);
      expect(result.data!.description, '');
    });

    test('generates identical URI and signature on repeated calls', () {
      final PaymentRequestData data = buildData();
      final Uri first = service.generateDeepLink(data, secretKey: testSecret);
      final Uri second = service.generateDeepLink(data, secretKey: testSecret);
      expect(first.toString(), second.toString());
      expect(
        first.queryParameters['signature'],
        second.queryParameters['signature'],
      );
    });
  });

  group('universal link round trip', () {
    test('generates an https://intbank.ro/pay link', () {
      final Uri uri =
          service.generateUniversalLink(buildData(), secretKey: testSecret);
      expect(uri.scheme, 'https');
      expect(uri.host, PaymentRequestDeepLinkService.universalLinkHost);
      expect(uri.path, '/pay');
    });

    test('parses and validates a freshly generated universal link', () {
      final PaymentRequestData data = buildData();
      final Uri uri =
          service.generateUniversalLink(data, secretKey: testSecret);
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.valid);
      expect(result.data!.iban, data.iban);
    });
  });

  group('tampering', () {
    test('detects an altered amount', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'amount', '999.99'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.tamperedSignature);
    });

    test('detects an altered IBAN', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'iban', 'RO00EVIL0000000000000000'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.tamperedSignature);
    });

    test('detects an altered recipient', () {
      final Uri uri =
          service.generateUniversalLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'recipientName', 'Mallory'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.tamperedSignature);
    });

    test('detects a modified signature string', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final String wrongSignature = List<String>.filled(64, '0').join();
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'signature', wrongSignature),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.tamperedSignature);
    });

    test('rejects a link signed with a different secret', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: 'other-secret');
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.tamperedSignature);
    });
  });

  group('expiry', () {
    test('reports expired when currentTime is after expiresAt', () {
      final PaymentRequestData data = buildData(expiresAt: pastExpiry);
      final Uri uri = service.generateDeepLink(data, secretKey: testSecret);
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.expired);
      expect(result.isValid, isFalse);
      expect(result.data, isNotNull);
    });

    test('is valid exactly on the expiresAt instant', () {
      final PaymentRequestData data = buildData(expiresAt: fixedNow);
      final Uri uri = service.generateDeepLink(data, secretKey: testSecret);
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        uri,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.valid);
    });
  });

  group('scheme handling', () {
    test('rejects an unknown custom scheme', () {
      final Uri valid =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri evil = Uri(
        scheme: 'evil',
        host: 'pay',
        queryParameters: valid.queryParameters,
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        evil,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.unsupportedScheme);
    });

    test('rejects an unknown universal link host', () {
      final Uri valid =
          service.generateUniversalLink(buildData(), secretKey: testSecret);
      final Uri evil = Uri(
        scheme: 'https',
        host: 'evil.example',
        path: '/pay',
        queryParameters: valid.queryParameters,
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        evil,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.unsupportedScheme);
    });
  });

  group('invalid format', () {
    test('rejects a link missing required parameters', () {
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        Uri.parse('intbank://pay?amount=10.0'),
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a link with an empty signature parameter', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri emptySignature =
          uri.replace(queryParameters: withOverride(uri, 'signature', ''));
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        emptySignature,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a non-numeric amount', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'amount', 'not-a-number'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a non-positive amount', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'amount', '0'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a malformed expiresAt', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'expiresAt', 'not-a-date'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a wrong deep link host', () {
      final Uri valid =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri wrongHost = Uri(
        scheme: 'intbank',
        host: 'wronghost',
        queryParameters: valid.queryParameters,
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        wrongHost,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects a wrong universal link path', () {
      final Uri valid =
          service.generateUniversalLink(buildData(), secretKey: testSecret);
      final Uri wrongPath = Uri(
        scheme: 'https',
        host: 'intbank.ro',
        path: '/other',
        queryParameters: valid.queryParameters,
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        wrongPath,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects an over-length description', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'description', 'x' * 300),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects unknown query parameters', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = uri.replace(
        queryParameters: withOverride(uri, 'injected', 'value'),
      );
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });

    test('rejects duplicate query parameters', () {
      final Uri uri =
          service.generateDeepLink(buildData(), secretKey: testSecret);
      final Uri tampered = Uri.parse('$uri&amount=999.99');
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        tampered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.invalidFormat);
    });
  });

  group('canonical ordering stability', () {
    test('validates when query parameters are reordered', () {
      final PaymentRequestData data = buildData();
      final Uri uri = service.generateDeepLink(data, secretKey: testSecret);
      final Map<String, String> reversed = <String, String>{};
      for (final String key in uri.queryParameters.keys.toList().reversed) {
        reversed[key] = uri.queryParameters[key]!;
      }
      final Uri reordered = uri.replace(queryParameters: reversed);
      expect(reordered.toString(), isNot(uri.toString()));
      final PaymentRequestParseResult result = service.parseAndValidateUri(
        reordered,
        secretKey: testSecret,
        currentTime: fixedNow,
      );
      expect(result.status, PaymentLinkValidationStatus.valid);
    });
  });

  group('robustness', () {
    test('never throws for arbitrary malformed input', () {
      final List<Uri> inputs = <Uri>[
        Uri.parse('intbank://pay'),
        Uri.parse('intbank://'),
        Uri.parse('https://intbank.ro'),
        Uri.parse('intbank://pay?amount=1&amount=2'),
        Uri.parse('mailto:test@example.com'),
        Uri.parse('https://intbank.ro/other/path?x=1'),
      ];
      for (final Uri uri in inputs) {
        final PaymentRequestParseResult result = service.parseAndValidateUri(
          uri,
          secretKey: testSecret,
          currentTime: fixedNow,
        );
        expect(result.isValid, isFalse);
      }
    });
  });
}
