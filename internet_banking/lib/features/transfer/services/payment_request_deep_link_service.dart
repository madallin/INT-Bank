import 'package:flutter/foundation.dart';

/// Validation status returned by
/// [PaymentRequestDeepLinkService.parseAndValidateUri].
enum PaymentLinkValidationStatus {
  /// The link is well formed, correctly signed and not expired.
  valid,

  /// The signature matches but the request expiry is in the past.
  expired,

  /// The provided signature does not match the canonical parameters.
  tamperedSignature,

  /// One or more required parameters are missing or malformed.
  invalidFormat,

  /// The URI scheme or authority is not supported by this application.
  unsupportedScheme,
}

/// Immutable value object describing a peer to peer payment request.
@immutable
class PaymentRequestData {
  /// Stable identifier of the recipient account owner.
  final String recipientId;

  /// Human readable recipient name.
  final String recipientName;

  /// International Bank Account Number of the recipient.
  final String iban;

  /// Requested amount, strictly greater than zero.
  final double amount;

  /// ISO 4217 currency code, for example RON or EUR.
  final String currency;

  /// Optional free form description, empty when not provided.
  final String description;

  /// Instant after which the request must be rejected.
  final DateTime expiresAt;

  /// Lower-case hexadecimal HMAC signature. May be empty for unsigned input.
  final String signature;

  const PaymentRequestData({
    required this.recipientId,
    required this.recipientName,
    required this.iban,
    required this.amount,
    required this.currency,
    this.description = '',
    required this.expiresAt,
    this.signature = '',
  });

  PaymentRequestData copyWith({
    String? recipientId,
    String? recipientName,
    String? iban,
    double? amount,
    String? currency,
    String? description,
    DateTime? expiresAt,
    String? signature,
  }) {
    return PaymentRequestData(
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      iban: iban ?? this.iban,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      expiresAt: expiresAt ?? this.expiresAt,
      signature: signature ?? this.signature,
    );
  }

  @override
  String toString() {
    return 'PaymentRequestData('
        'recipientId: $recipientId, '
        'recipientName: $recipientName, '
        'iban: $iban, '
        'amount: $amount, '
        'currency: $currency, '
        'description: $description, '
        'expiresAt: ${expiresAt.toUtc().toIso8601String()}, '
        'signature: $signature)';
  }
}

/// Immutable outcome of parsing and validating a payment request link.
@immutable
class PaymentRequestParseResult {
  /// Validation outcome.
  final PaymentLinkValidationStatus status;

  /// Parsed payload, available only when [status] is
  /// [PaymentLinkValidationStatus.valid] or
  /// [PaymentLinkValidationStatus.expired].
  final PaymentRequestData? data;

  /// Optional human readable explanation, never containing secrets.
  final String? message;

  const PaymentRequestParseResult({
    required this.status,
    this.data,
    this.message,
  });

  /// Whether the link is valid, signed and not expired.
  bool get isValid =>
      status == PaymentLinkValidationStatus.valid && data != null;
}

/// Generates and validates signed peer to peer payment request deep links.
///
/// Canonicalisation rules used for signing:
/// The HMAC-SHA256 input is the canonical query string built by
/// [buildCanonicalQueryString]. Parameters are emitted in a fixed order:
/// amount, currency, description, expiresAt, iban, recipientId, recipientName.
/// The signature parameter is never part of the signed payload. Values are
/// percent-encoded with upper-case hexadecimal escapes over the UTF-8 bytes,
/// leaving only the RFC 3986 unreserved characters unescaped. The expiresAt
/// value is normalised to UTC ISO-8601 before signing.
///
/// The resulting signature is emitted as lower-case hexadecimal.
class PaymentRequestDeepLinkService {
  /// Custom application scheme used by the deep links.
  static const String deepLinkScheme = 'intbank';

  /// Authority used by the universal links.
  static const String universalLinkHost = 'intbank.ro';

  static const int _maxRecipientIdLength = 128;
  static const int _maxRecipientNameLength = 128;
  static const int _maxIbanLength = 64;
  static const int _maxCurrencyLength = 8;
  static const int _maxDescriptionLength = 256;
  static const int _maxSignatureLength = 128;

  static const Set<String> _requiredParameters = <String>{
    'amount',
    'currency',
    'expiresAt',
    'iban',
    'recipientId',
    'recipientName',
    'signature',
  };

  static const Set<String> _allowedParameters = <String>{
    'amount',
    'currency',
    'description',
    'expiresAt',
    'iban',
    'recipientId',
    'recipientName',
    'signature',
  };

  /// Builds the deterministic canonical query string that is signed.
  String buildCanonicalQueryString(PaymentRequestData data) {
    final String amount = _percentEncode(data.amount.toString());
    final String currency = _percentEncode(data.currency);
    final String description = _percentEncode(data.description);
    final String expiresAt =
        _percentEncode(data.expiresAt.toUtc().toIso8601String());
    final String iban = _percentEncode(data.iban);
    final String recipientId = _percentEncode(data.recipientId);
    final String recipientName = _percentEncode(data.recipientName);
    return 'amount=$amount'
        '&currency=$currency'
        '&description=$description'
        '&expiresAt=$expiresAt'
        '&iban=$iban'
        '&recipientId=$recipientId'
        '&recipientName=$recipientName';
  }

  /// Computes the lower-case hexadecimal HMAC-SHA256 signature for [data].
  String computeSignature(
    PaymentRequestData data, {
    required String secretKey,
  }) {
    final String canonical = buildCanonicalQueryString(data);
    return _toHex(_hmacSha256(_utf8Encode(secretKey), _utf8Encode(canonical)));
  }

  /// Generates an `intbank://pay?...` deep link for [data].
  Uri generateDeepLink(
    PaymentRequestData data, {
    required String secretKey,
  }) {
    return Uri(
      scheme: deepLinkScheme,
      host: 'pay',
      queryParameters: _signedQueryParameters(data, secretKey),
    );
  }

  /// Generates an `https://intbank.ro/pay?...` universal link for [data].
  Uri generateUniversalLink(
    PaymentRequestData data, {
    required String secretKey,
  }) {
    return Uri(
      scheme: 'https',
      host: universalLinkHost,
      path: '/pay',
      queryParameters: _signedQueryParameters(data, secretKey),
    );
  }

  /// Parses [uri], recomputes the signature from the parsed parameters and
  /// validates it against [secretKey] and [currentTime].
  ///
  /// This method never throws. Any malformed input results in a result whose
  /// status is [PaymentLinkValidationStatus.invalidFormat].
  PaymentRequestParseResult parseAndValidateUri(
    Uri uri, {
    required String secretKey,
    required DateTime currentTime,
  }) {
    try {
      final String scheme = uri.scheme;
      if (scheme == deepLinkScheme) {
        if (uri.host != 'pay') {
          return _failure(
            PaymentLinkValidationStatus.invalidFormat,
            'Deep link host must be "pay".',
          );
        }
      } else if (scheme == 'https') {
        if (uri.host != universalLinkHost) {
          return _failure(
            PaymentLinkValidationStatus.unsupportedScheme,
            'Universal link host must be "$universalLinkHost".',
          );
        }
        if (uri.path != '/pay') {
          return _failure(
            PaymentLinkValidationStatus.invalidFormat,
            'Universal link path must be "/pay".',
          );
        }
      } else {
        return _failure(
          PaymentLinkValidationStatus.unsupportedScheme,
          'Unsupported URI scheme.',
        );
      }

      final Map<String, List<String>> allParameters = uri.queryParametersAll;
      for (final MapEntry<String, List<String>> entry
          in allParameters.entries) {
        if (!_allowedParameters.contains(entry.key)) {
          return _failure(
            PaymentLinkValidationStatus.invalidFormat,
            'Unknown parameter: ${entry.key}.',
          );
        }
        if (entry.value.length != 1) {
          return _failure(
            PaymentLinkValidationStatus.invalidFormat,
            'Duplicate parameter: ${entry.key}.',
          );
        }
      }

      final Map<String, String> parameters = uri.queryParameters;

      for (final String key in _requiredParameters) {
        final String? value = parameters[key];
        if (value == null || value.isEmpty) {
          return _failure(
            PaymentLinkValidationStatus.invalidFormat,
            'Missing required parameter: $key.',
          );
        }
      }

      final String amountRaw = parameters['amount']!;
      final double? amount = double.tryParse(amountRaw);
      if (amount == null || !amount.isFinite || amount <= 0) {
        return _failure(
          PaymentLinkValidationStatus.invalidFormat,
          'Invalid amount.',
        );
      }

      final String expiresAtRaw = parameters['expiresAt']!;
      final DateTime? expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt == null) {
        return _failure(
          PaymentLinkValidationStatus.invalidFormat,
          'Invalid expiresAt.',
        );
      }

      final String recipientId = parameters['recipientId']!;
      final String recipientName = parameters['recipientName']!;
      final String iban = parameters['iban']!;
      final String currency = parameters['currency']!;
      final String signature = parameters['signature']!;
      final String description = parameters['description'] ?? '';

      if (recipientId.length > _maxRecipientIdLength ||
          recipientName.length > _maxRecipientNameLength ||
          iban.length > _maxIbanLength ||
          currency.length > _maxCurrencyLength ||
          description.length > _maxDescriptionLength ||
          signature.length > _maxSignatureLength) {
        return _failure(
          PaymentLinkValidationStatus.invalidFormat,
          'Parameter exceeds maximum length.',
        );
      }

      final PaymentRequestData data = PaymentRequestData(
        recipientId: recipientId,
        recipientName: recipientName,
        iban: iban,
        amount: amount,
        currency: currency,
        description: description,
        expiresAt: expiresAt.toUtc(),
        signature: signature,
      );

      final String expectedSignature = computeSignature(
        data,
        secretKey: secretKey,
      );
      if (!_constantTimeEquals(expectedSignature, signature)) {
        return _failure(
          PaymentLinkValidationStatus.tamperedSignature,
          'Signature mismatch.',
        );
      }

      if (currentTime.isAfter(data.expiresAt)) {
        return PaymentRequestParseResult(
          status: PaymentLinkValidationStatus.expired,
          data: data,
          message: 'Payment request has expired.',
        );
      }

      return PaymentRequestParseResult(
        status: PaymentLinkValidationStatus.valid,
        data: data,
      );
    } catch (_) {
      return _failure(
        PaymentLinkValidationStatus.invalidFormat,
        'Malformed payment link.',
      );
    }
  }

  Map<String, String> _signedQueryParameters(
    PaymentRequestData data,
    String secretKey,
  ) {
    return <String, String>{
      'amount': data.amount.toString(),
      'currency': data.currency,
      'description': data.description,
      'expiresAt': data.expiresAt.toUtc().toIso8601String(),
      'iban': data.iban,
      'recipientId': data.recipientId,
      'recipientName': data.recipientName,
      'signature': computeSignature(data, secretKey: secretKey),
    };
  }

  /// Exposes the raw SHA-256 digest for known-answer tests only.
  @visibleForTesting
  static String debugSha256Hex(String input) =>
      _toHex(_Sha256.hash(_utf8Encode(input)));

  /// Exposes the raw HMAC-SHA256 digest for known-answer tests only.
  @visibleForTesting
  static String debugHmacSha256Hex(String key, String message) =>
      _toHex(_hmacSha256(_utf8Encode(key), _utf8Encode(message)));
}

PaymentRequestParseResult _failure(
  PaymentLinkValidationStatus status,
  String message,
) {
  return PaymentRequestParseResult(status: status, message: message);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  int difference = 0;
  for (int i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

const String _hexDigits = '0123456789abcdef';
const String _upperHexDigits = '0123456789ABCDEF';

bool _isUnreserved(int byte) {
  return (byte >= 0x41 && byte <= 0x5A) ||
      (byte >= 0x61 && byte <= 0x7A) ||
      (byte >= 0x30 && byte <= 0x39) ||
      byte == 0x2D ||
      byte == 0x5F ||
      byte == 0x2E ||
      byte == 0x7E;
}

String _percentEncode(String value) {
  final List<int> bytes = _utf8Encode(value);
  final StringBuffer buffer = StringBuffer();
  for (final int byte in bytes) {
    if (_isUnreserved(byte)) {
      buffer.writeCharCode(byte);
    } else {
      buffer.write('%');
      buffer.write(_upperHexDigits[(byte >> 4) & 0x0F]);
      buffer.write(_upperHexDigits[byte & 0x0F]);
    }
  }
  return buffer.toString();
}

String _toHex(List<int> bytes) {
  final StringBuffer buffer = StringBuffer();
  for (final int byte in bytes) {
    buffer.write(_hexDigits[(byte >> 4) & 0x0F]);
    buffer.write(_hexDigits[byte & 0x0F]);
  }
  return buffer.toString();
}

List<int> _utf8Encode(String input) {
  final List<int> bytes = <int>[];
  for (final int rune in input.runes) {
    if (rune <= 0x7F) {
      bytes.add(rune);
    } else if (rune <= 0x7FF) {
      bytes.add(0xC0 | (rune >> 6));
      bytes.add(0x80 | (rune & 0x3F));
    } else if (rune <= 0xFFFF) {
      bytes.add(0xE0 | (rune >> 12));
      bytes.add(0x80 | ((rune >> 6) & 0x3F));
      bytes.add(0x80 | (rune & 0x3F));
    } else {
      bytes.add(0xF0 | (rune >> 18));
      bytes.add(0x80 | ((rune >> 12) & 0x3F));
      bytes.add(0x80 | ((rune >> 6) & 0x3F));
      bytes.add(0x80 | (rune & 0x3F));
    }
  }
  return bytes;
}

List<int> _hmacSha256(List<int> key, List<int> message) {
  const int blockSize = 64;
  final List<int> normalizedKey = key.length > blockSize
      ? _Sha256.hash(key)
      : List<int>.from(key);

  final List<int> paddedKey = List<int>.filled(blockSize, 0);
  for (int i = 0; i < normalizedKey.length && i < blockSize; i++) {
    paddedKey[i] = normalizedKey[i] & 0xFF;
  }

  final List<int> outerPad = List<int>.filled(blockSize, 0);
  final List<int> innerPad = List<int>.filled(blockSize, 0);
  for (int i = 0; i < blockSize; i++) {
    outerPad[i] = paddedKey[i] ^ 0x5C;
    innerPad[i] = paddedKey[i] ^ 0x36;
  }

  final List<int> innerInput = <int>[...innerPad, ...message];
  final List<int> innerHash = _Sha256.hash(innerInput);
  final List<int> outerInput = <int>[...outerPad, ...innerHash];
  return _Sha256.hash(outerInput);
}

class _Sha256 {
  static const int _mask32 = 0xFFFFFFFF;

  static const List<int> _roundConstants = <int>[
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
  ];

  static List<int> hash(List<int> message) {
    int h0 = 0x6A09E667;
    int h1 = 0xBB67AE85;
    int h2 = 0x3C6EF372;
    int h3 = 0xA54FF53A;
    int h4 = 0x510E527F;
    int h5 = 0x9B05688C;
    int h6 = 0x1F83D9AB;
    int h7 = 0x5BE0CD19;

    final List<int> padded = _pad(message);
    final int blockCount = padded.length ~/ 64;
    final List<int> schedule = List<int>.filled(64, 0);

    for (int block = 0; block < blockCount; block++) {
      final int offset = block * 64;
      for (int index = 0; index < 16; index++) {
        final int base = offset + index * 4;
        schedule[index] = ((padded[base] & 0xFF) << 24) |
            ((padded[base + 1] & 0xFF) << 16) |
            ((padded[base + 2] & 0xFF) << 8) |
            (padded[base + 3] & 0xFF);
      }
      for (int index = 16; index < 64; index++) {
        final int value = schedule[index - 15];
        final int value2 = schedule[index - 2];
        final int sigma0 =
            _rotateRight(value, 7) ^ _rotateRight(value, 18) ^ (value >> 3);
        final int sigma1 = _rotateRight(value2, 17) ^
            _rotateRight(value2, 19) ^
            (value2 >> 10);
        schedule[index] = (schedule[index - 16] +
                sigma0 +
                schedule[index - 7] +
                sigma1) &
            _mask32;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int index = 0; index < 64; index++) {
        final int sigma1 =
            _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
        final int choice = (e & f) ^ ((~e & _mask32) & g);
        final int temp1 =
            (h + sigma1 + choice + _roundConstants[index] + schedule[index]) &
                _mask32;
        final int sigma0 =
            _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
        final int majority = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (sigma0 + majority) & _mask32;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }

      h0 = (h0 + a) & _mask32;
      h1 = (h1 + b) & _mask32;
      h2 = (h2 + c) & _mask32;
      h3 = (h3 + d) & _mask32;
      h4 = (h4 + e) & _mask32;
      h5 = (h5 + f) & _mask32;
      h6 = (h6 + g) & _mask32;
      h7 = (h7 + h) & _mask32;
    }

    final List<int> digest = List<int>.filled(32, 0);
    final List<int> words = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
    for (int index = 0; index < 8; index++) {
      digest[index * 4] = (words[index] >> 24) & 0xFF;
      digest[index * 4 + 1] = (words[index] >> 16) & 0xFF;
      digest[index * 4 + 2] = (words[index] >> 8) & 0xFF;
      digest[index * 4 + 3] = words[index] & 0xFF;
    }
    return digest;
  }

  static int _rotateRight(int value, int shift) {
    return ((value >> shift) | (value << (32 - shift))) & _mask32;
  }

  static List<int> _pad(List<int> message) {
    final int messageLength = message.length;
    final int bitLength = messageLength * 8;
    final int remainder = (messageLength + 9) % 64;
    final int zeroPadding = remainder == 0 ? 0 : 64 - remainder;
    final List<int> result =
        List<int>.filled(messageLength + 1 + zeroPadding + 8, 0);
    for (int i = 0; i < messageLength; i++) {
      result[i] = message[i] & 0xFF;
    }
    result[messageLength] = 0x80;
    final int lengthPosition = result.length - 8;
    result[lengthPosition] = (bitLength >> 56) & 0xFF;
    result[lengthPosition + 1] = (bitLength >> 48) & 0xFF;
    result[lengthPosition + 2] = (bitLength >> 40) & 0xFF;
    result[lengthPosition + 3] = (bitLength >> 32) & 0xFF;
    result[lengthPosition + 4] = (bitLength >> 24) & 0xFF;
    result[lengthPosition + 5] = (bitLength >> 16) & 0xFF;
    result[lengthPosition + 6] = (bitLength >> 8) & 0xFF;
    result[lengthPosition + 7] = bitLength & 0xFF;
    return result;
  }
}
