import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Lifecycle classification for a virtual card.
enum VirtualCardType { disposableSingleUse, multiUseVirtual }

/// Operational status for a virtual card.
enum CardStatus { active, frozen, expired, burned }

/// Immutable domain model describing a single virtual card.
@immutable
class VirtualCard {
  final String id;
  final String cardNumber;
  final String cardHolderName;
  final int expiryMonth;
  final int expiryYear;
  final VirtualCardType type;
  final CardStatus status;
  final double spendingLimit;
  final double spentThisPeriod;

  const VirtualCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.type,
    this.status = CardStatus.active,
    required this.spendingLimit,
    this.spentThisPeriod = 0.0,
  });

  /// True when the card can currently be used for authorizations.
  bool get isActive => status == CardStatus.active;

  /// True when the card expiry has passed at [now].
  ///
  /// A card remains valid through the final day of its expiry month, so it is
  /// only considered expired once [now] moves into a later month.
  bool isExpiredAt(DateTime now) {
    if (now.year > expiryYear) {
      return true;
    }
    if (now.year == expiryYear && now.month > expiryMonth) {
      return true;
    }
    return false;
  }

  VirtualCard copyWith({
    String? id,
    String? cardNumber,
    String? cardHolderName,
    int? expiryMonth,
    int? expiryYear,
    VirtualCardType? type,
    CardStatus? status,
    double? spendingLimit,
    double? spentThisPeriod,
  }) {
    return VirtualCard(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      type: type ?? this.type,
      status: status ?? this.status,
      spendingLimit: spendingLimit ?? this.spendingLimit,
      spentThisPeriod: spentThisPeriod ?? this.spentThisPeriod,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VirtualCard &&
        other.id == id &&
        other.cardNumber == cardNumber &&
        other.cardHolderName == cardHolderName &&
        other.expiryMonth == expiryMonth &&
        other.expiryYear == expiryYear &&
        other.type == type &&
        other.status == status &&
        other.spendingLimit == spendingLimit &&
        other.spentThisPeriod == spentThisPeriod;
  }

  @override
  int get hashCode => Object.hash(
        id,
        cardNumber,
        cardHolderName,
        expiryMonth,
        expiryYear,
        type,
        status,
        spendingLimit,
        spentThisPeriod,
      );

  @override
  String toString() =>
      'VirtualCard(id: $id, type: $type, status: $status, '
      'spentThisPeriod: $spentThisPeriod, spendingLimit: $spendingLimit)';
}

/// Immutable snapshot of a rolling dynamic CVV and its validity window.
@immutable
class DynamicCvvState {
  final String currentCvv;
  final int secondsRemaining;
  final int totalPeriodSeconds;

  const DynamicCvvState({
    required this.currentCvv,
    required this.secondsRemaining,
    required this.totalPeriodSeconds,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DynamicCvvState &&
        other.currentCvv == currentCvv &&
        other.secondsRemaining == secondsRemaining &&
        other.totalPeriodSeconds == totalPeriodSeconds;
  }

  @override
  int get hashCode =>
      Object.hash(currentCvv, secondsRemaining, totalPeriodSeconds);

  @override
  String toString() =>
      'DynamicCvvState(currentCvv: $currentCvv, '
      'secondsRemaining: $secondsRemaining, '
      'totalPeriodSeconds: $totalPeriodSeconds)';
}

/// Domain service providing virtual card lifecycle and dynamic CVV logic.
///
/// All time dependent operations accept the current time explicitly so the
/// behaviour is fully deterministic and reproducible in tests.
class VirtualCardService {
  const VirtualCardService();

  static const int _defaultPeriodSeconds = 300;

  /// Validates a primary account number using the Luhn mod-10 algorithm.
  ///
  /// Spaces and dashes are ignored. Any other non-digit character invalidates
  /// the input.
  bool isValidPan(String pan) {
    final String digits = pan.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.length < 2) {
      return false;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
      return false;
    }
    int sum = 0;
    bool doubleDigit = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int digit = digits.codeUnitAt(i) - 0x30;
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  /// Returns a masked representation that retains only the final four digits.
  String maskPan(String pan) {
    final String digits = pan.replaceAll(RegExp(r'[^0-9]'), '');
    final String last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits.padLeft(4, '0');
    return '**** **** **** $last4';
  }

  /// Computes the RFC 6238 style time-based three digit dynamic CVV.
  ///
  /// The counter is derived from [currentTime] in UTC seconds divided by
  /// [periodSeconds], encoded as an eight byte big-endian value, signed with
  /// HMAC-SHA256 and reduced to three digits using dynamic truncation.
  DynamicCvvState computeDynamicCvv({
    required String cardSecret,
    required DateTime currentTime,
    int periodSeconds = _defaultPeriodSeconds,
  }) {
    if (periodSeconds <= 0) {
      throw ArgumentError.value(
        periodSeconds,
        'periodSeconds',
        'periodSeconds must be greater than zero.',
      );
    }
    final int secondsSinceEpoch =
        currentTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final int counter = secondsSinceEpoch ~/ periodSeconds;
    final String cvv = _cvvForCounter(cardSecret, counter);
    final int secondsRemaining =
        periodSeconds - (secondsSinceEpoch % periodSeconds);
    return DynamicCvvState(
      currentCvv: cvv,
      secondsRemaining: secondsRemaining,
      totalPeriodSeconds: periodSeconds,
    );
  }

  /// Verifies a candidate CVV allowing for clock skew of +/- [window] steps.
  bool verifyCvv({
    required String cardSecret,
    required String candidateCvv,
    required DateTime currentTime,
    int periodSeconds = _defaultPeriodSeconds,
    int window = 1,
  }) {
    if (periodSeconds <= 0) {
      throw ArgumentError.value(
        periodSeconds,
        'periodSeconds',
        'periodSeconds must be greater than zero.',
      );
    }
    if (window < 0) {
      throw ArgumentError.value(
        window,
        'window',
        'window must not be negative.',
      );
    }
    final int secondsSinceEpoch =
        currentTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final int counter = secondsSinceEpoch ~/ periodSeconds;
    for (int offset = -window; offset <= window; offset++) {
      if (_cvvForCounter(cardSecret, counter + offset) == candidateCvv) {
        return true;
      }
    }
    return false;
  }

  /// Transitions an active card to [CardStatus.frozen].
  ///
  /// Cards that are not active are returned unchanged.
  VirtualCard freezeCard(VirtualCard card) {
    if (card.status != CardStatus.active) {
      return card;
    }
    return card.copyWith(status: CardStatus.frozen);
  }

  /// Transitions a frozen card back to [CardStatus.active].
  ///
  /// Cards that are not frozen are returned unchanged.
  VirtualCard unfreezeCard(VirtualCard card) {
    if (card.status != CardStatus.frozen) {
      return card;
    }
    return card.copyWith(status: CardStatus.active);
  }

  /// Permanently burns a disposable card.
  ///
  /// Multi-use cards are returned unchanged.
  VirtualCard burnDisposableCard(VirtualCard card) {
    if (card.type != VirtualCardType.disposableSingleUse) {
      return card;
    }
    return card.copyWith(status: CardStatus.burned);
  }

  /// Determines whether a transaction of [amount] may be authorized.
  ///
  /// Authorization requires an active status, a strictly positive amount, an
  /// unexpired card at [now] when provided, and sufficient remaining limit.
  bool canAuthorizeTransaction(
    VirtualCard card,
    double amount, {
    DateTime? now,
  }) {
    if (card.status != CardStatus.active) {
      return false;
    }
    if (amount <= 0) {
      return false;
    }
    if (now != null && card.isExpiredAt(now)) {
      return false;
    }
    if (card.spentThisPeriod + amount > card.spendingLimit) {
      return false;
    }
    return true;
  }

  /// Authorizes a transaction and returns the updated card.
  ///
  /// Throws [StateError] when [canAuthorizeTransaction] is false. Disposable
  /// cards are burned once the transaction is applied.
  VirtualCard authorizeTransaction(
    VirtualCard card,
    double amount, {
    DateTime? now,
  }) {
    if (!canAuthorizeTransaction(card, amount, now: now)) {
      throw StateError(
        'Transaction of $amount is not authorized for card ${card.id}.',
      );
    }
    final VirtualCard updated = card.copyWith(
      spentThisPeriod: card.spentThisPeriod + amount,
    );
    if (card.type == VirtualCardType.disposableSingleUse) {
      return updated.copyWith(status: CardStatus.burned);
    }
    return updated;
  }

  /// Computes the three digit CVV for the supplied TOTP [counter].
  String _cvvForCounter(String secret, int counter) {
    final Uint8List message = _counterToBytes(counter);
    final Uint8List mac = _hmacSha256(_utf8Encode(secret), message);
    final int truncated = _dynamicTruncate(mac) % 1000;
    return truncated.toString().padLeft(3, '0');
  }

  /// Encodes [counter] as an eight byte big-endian sequence.
  static Uint8List _counterToBytes(int counter) {
    final Uint8List bytes = Uint8List(8);
    int value = counter;
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xff;
      value = value >> 8;
    }
    return bytes;
  }

  /// Applies RFC 4226 dynamic truncation and returns the 31-bit integer.
  static int _dynamicTruncate(Uint8List hash) {
    final int offset = hash[hash.length - 1] & 0x0f;
    return ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
  }

  /// Returns the lowercase hexadecimal SHA-256 digest of [message].
  ///
  /// Exposed only to allow validation against published known-answer vectors.
  @visibleForTesting
  static String sha256Hex(List<int> message) {
    return _toHex(_sha256(message));
  }

  /// Returns the lowercase hexadecimal HMAC-SHA256 of [message] under [key].
  ///
  /// Exposed only to allow validation against published known-answer vectors.
  @visibleForTesting
  static String hmacSha256Hex(List<int> key, List<int> message) {
    return _toHex(_hmacSha256(key, message));
  }

  static String _toHex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write((byte & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

/// Encodes [text] as UTF-8 bytes without relying on external packages.
Uint8List _utf8Encode(String text) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < text.length; i++) {
    int codePoint = text.codeUnitAt(i);
    if (codePoint >= 0xd800 &&
        codePoint <= 0xdbff &&
        i + 1 < text.length) {
      final int next = text.codeUnitAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        codePoint =
            0x10000 + ((codePoint - 0xd800) << 10) + (next - 0xdc00);
        i++;
      }
    }
    if (codePoint <= 0x7f) {
      bytes.add(codePoint);
    } else if (codePoint <= 0x7ff) {
      bytes.add(0xc0 | (codePoint >> 6));
      bytes.add(0x80 | (codePoint & 0x3f));
    } else if (codePoint <= 0xffff) {
      bytes.add(0xe0 | (codePoint >> 12));
      bytes.add(0x80 | ((codePoint >> 6) & 0x3f));
      bytes.add(0x80 | (codePoint & 0x3f));
    } else {
      bytes.add(0xf0 | (codePoint >> 18));
      bytes.add(0x80 | ((codePoint >> 12) & 0x3f));
      bytes.add(0x80 | ((codePoint >> 6) & 0x3f));
      bytes.add(0x80 | (codePoint & 0x3f));
    }
  }
  return Uint8List.fromList(bytes);
}

/// Computes the HMAC-SHA256 authentication code for [message] under [key].
Uint8List _hmacSha256(List<int> key, List<int> message) {
  const int blockSize = 64;
  List<int> normalizedKey = List<int>.from(key);
  if (normalizedKey.length > blockSize) {
    normalizedKey = _sha256(normalizedKey);
  }
  if (normalizedKey.length < blockSize) {
    normalizedKey = <int>[
      ...normalizedKey,
      ...List<int>.filled(blockSize - normalizedKey.length, 0),
    ];
  }
  final Uint8List outerPad = Uint8List(blockSize);
  final Uint8List innerPad = Uint8List(blockSize);
  for (int i = 0; i < blockSize; i++) {
    outerPad[i] = normalizedKey[i] ^ 0x5c;
    innerPad[i] = normalizedKey[i] ^ 0x36;
  }
  final Uint8List innerHash = _sha256(<int>[...innerPad, ...message]);
  return _sha256(<int>[...outerPad, ...innerHash]);
}

/// Computes the SHA-256 digest of [message].
Uint8List _sha256(List<int> message) {
  const List<int> k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  int h0 = 0x6a09e667;
  int h1 = 0xbb67ae85;
  int h2 = 0x3c6ef372;
  int h3 = 0xa54ff53a;
  int h4 = 0x510e527f;
  int h5 = 0x9b05688c;
  int h6 = 0x1f83d9ab;
  int h7 = 0x5be0cd19;

  final int originalLength = message.length;
  final int bitLength = originalLength * 8;

  int paddedLength = originalLength + 1;
  while (paddedLength % 64 != 56) {
    paddedLength++;
  }
  paddedLength += 8;

  final Uint8List padded = Uint8List(paddedLength);
  for (int i = 0; i < originalLength; i++) {
    padded[i] = message[i] & 0xff;
  }
  padded[originalLength] = 0x80;

  final int highBits = (bitLength ~/ 0x100000000) & 0xffffffff;
  final int lowBits = bitLength & 0xffffffff;
  padded[paddedLength - 8] = (highBits >> 24) & 0xff;
  padded[paddedLength - 7] = (highBits >> 16) & 0xff;
  padded[paddedLength - 6] = (highBits >> 8) & 0xff;
  padded[paddedLength - 5] = highBits & 0xff;
  padded[paddedLength - 4] = (lowBits >> 24) & 0xff;
  padded[paddedLength - 3] = (lowBits >> 16) & 0xff;
  padded[paddedLength - 2] = (lowBits >> 8) & 0xff;
  padded[paddedLength - 1] = lowBits & 0xff;

  final Uint32List w = Uint32List(64);
  for (int block = 0; block < paddedLength; block += 64) {
    for (int t = 0; t < 16; t++) {
      final int index = block + t * 4;
      w[t] = ((padded[index] & 0xff) << 24) |
          ((padded[index + 1] & 0xff) << 16) |
          ((padded[index + 2] & 0xff) << 8) |
          (padded[index + 3] & 0xff);
    }
    for (int t = 16; t < 64; t++) {
      final int s0 = _rotr(w[t - 15], 7) ^
          _rotr(w[t - 15], 18) ^
          (w[t - 15] >> 3);
      final int s1 = _rotr(w[t - 2], 17) ^
          _rotr(w[t - 2], 19) ^
          (w[t - 2] >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
    }

    int a = h0;
    int b = h1;
    int c = h2;
    int d = h3;
    int e = h4;
    int f = h5;
    int g = h6;
    int h = h7;

    for (int t = 0; t < 64; t++) {
      final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final int ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final int temp1 = (h + s1 + ch + k[t] + w[t]) & 0xffffffff;
      final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int temp2 = (s0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  final Uint8List digest = Uint8List(32);
  final List<int> words = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
  for (int i = 0; i < 8; i++) {
    final int word = words[i];
    digest[i * 4] = (word >> 24) & 0xff;
    digest[i * 4 + 1] = (word >> 16) & 0xff;
    digest[i * 4 + 2] = (word >> 8) & 0xff;
    digest[i * 4 + 3] = word & 0xff;
  }
  return digest;
}

/// Rotates a 32-bit [value] right by [shift] bits.
int _rotr(int value, int shift) {
  return ((value >> shift) | (value << (32 - shift))) & 0xffffffff;
}
