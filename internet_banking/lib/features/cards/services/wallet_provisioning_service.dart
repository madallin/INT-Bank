import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Supported digital wallet platforms for card push provisioning.
enum WalletType { applePay, googleWallet }

/// Outcome classification for a wallet provisioning eligibility check.
enum WalletEligibilityStatus {
  eligible,
  alreadyAdded,
  unsupportedDevice,
  cardNotEligible,
}

/// Immutable result of an eligibility evaluation for a single card.
@immutable
class WalletEligibility {
  final WalletEligibilityStatus status;
  final WalletType walletType;
  final String cardId;

  const WalletEligibility({
    required this.status,
    required this.walletType,
    required this.cardId,
  });

  /// True when the card may be provisioned into the requested wallet.
  bool get isEligible => status == WalletEligibilityStatus.eligible;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WalletEligibility &&
        other.status == status &&
        other.walletType == walletType &&
        other.cardId == cardId;
  }

  @override
  int get hashCode => Object.hash(status, walletType, cardId);

  @override
  String toString() =>
      'WalletEligibility(status: $status, walletType: $walletType, '
      'cardId: $cardId)';
}

/// Immutable tokenization payload handed to a wallet platform bridge.
@immutable
class WalletProvisioningPayload {
  final WalletType walletType;
  final String encryptedCardData;
  final String nonce;
  final String ephemeralPublicKey;
  final String deviceAccountIdentifier;
  final String payloadVersion;

  const WalletProvisioningPayload({
    required this.walletType,
    required this.encryptedCardData,
    required this.nonce,
    required this.ephemeralPublicKey,
    required this.deviceAccountIdentifier,
    required this.payloadVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WalletProvisioningPayload &&
        other.walletType == walletType &&
        other.encryptedCardData == encryptedCardData &&
        other.nonce == nonce &&
        other.ephemeralPublicKey == ephemeralPublicKey &&
        other.deviceAccountIdentifier == deviceAccountIdentifier &&
        other.payloadVersion == payloadVersion;
  }

  @override
  int get hashCode => Object.hash(
        walletType,
        encryptedCardData,
        nonce,
        ephemeralPublicKey,
        deviceAccountIdentifier,
        payloadVersion,
      );

  @override
  String toString() =>
      'WalletProvisioningPayload(walletType: $walletType, '
      'payloadVersion: $payloadVersion, nonce: $nonce, '
      'deviceAccountIdentifier: $deviceAccountIdentifier)';
}

/// Abstraction over the native wallet capabilities of the host device.
abstract class WalletPlatformBridge {
  bool supportsApplePay();

  bool supportsGoogleWallet();

  List<String> provisionedCardTokens();
}

/// Domain service implementing wallet push provisioning orchestration.
///
/// Device capability checks are delegated to a [WalletPlatformBridge] so the
/// full flow remains deterministic and unit testable.
class WalletProvisioningService {
  static const String _applePayloadVersion = 'PKAddPasses.v1';
  static const String _googlePayloadVersion = 'TAP_AND_PAY.v2';

  final WalletPlatformBridge bridge;
  final List<String> _provisionedWallets = <String>[];

  WalletProvisioningService(this.bridge);

  /// Tokens recorded for successfully provisioned wallet cards.
  ///
  /// Each entry is formatted as `walletType:cardId`.
  List<String> get provisionedWallets =>
      List<String>.unmodifiable(_provisionedWallets);

  /// Resolves the eligibility of [cardId] for [walletType].
  ///
  /// Evaluation order is: unsupported device, then already added, then card
  /// eligibility, otherwise eligible.
  WalletEligibility checkEligibility({
    required WalletType walletType,
    required String cardId,
    required bool isCardEligible,
  }) {
    if (!_isDeviceSupported(walletType)) {
      return WalletEligibility(
        status: WalletEligibilityStatus.unsupportedDevice,
        walletType: walletType,
        cardId: cardId,
      );
    }
    if (bridge.provisionedCardTokens().contains(cardId)) {
      return WalletEligibility(
        status: WalletEligibilityStatus.alreadyAdded,
        walletType: walletType,
        cardId: cardId,
      );
    }
    if (!isCardEligible) {
      return WalletEligibility(
        status: WalletEligibilityStatus.cardNotEligible,
        walletType: walletType,
        cardId: cardId,
      );
    }
    return WalletEligibility(
      status: WalletEligibilityStatus.eligible,
      walletType: walletType,
      cardId: cardId,
    );
  }

  /// Builds the deterministic tokenization payload for [cardId].
  ///
  /// All derived values come from the SHA-256 digest of
  /// `cardId|deviceAccountIdentifier|generatedAt utc iso8601|walletType`.
  WalletProvisioningPayload buildProvisioningPayload({
    required WalletType walletType,
    required String cardId,
    required String deviceAccountIdentifier,
    required DateTime generatedAt,
  }) {
    final String material =
        '$cardId|$deviceAccountIdentifier|'
        '${generatedAt.toUtc().toIso8601String()}|$walletType';
    final String hash = sha256Hex(_utf8Encode(material));
    final String nonce = hash.substring(0, 16);
    final String ephemeralPublicKey = hash.substring(16, 48);
    final String encryptedCardData = hash.substring(48);
    return WalletProvisioningPayload(
      walletType: walletType,
      encryptedCardData: encryptedCardData,
      nonce: nonce,
      ephemeralPublicKey: ephemeralPublicKey,
      deviceAccountIdentifier: deviceAccountIdentifier,
      payloadVersion: _payloadVersionFor(walletType),
    );
  }

  /// Records that [cardId] was provisioned into [walletType].
  void recordProvisioned(WalletType walletType, String cardId) {
    final String token = '${walletType.name}:$cardId';
    if (!_provisionedWallets.contains(token)) {
      _provisionedWallets.add(token);
    }
  }

  bool _isDeviceSupported(WalletType walletType) {
    switch (walletType) {
      case WalletType.applePay:
        return bridge.supportsApplePay();
      case WalletType.googleWallet:
        return bridge.supportsGoogleWallet();
    }
  }

  String _payloadVersionFor(WalletType walletType) {
    switch (walletType) {
      case WalletType.applePay:
        return _applePayloadVersion;
      case WalletType.googleWallet:
        return _googlePayloadVersion;
    }
  }

  /// Returns the lowercase hexadecimal SHA-256 digest of [message].
  ///
  /// Exposed only to allow validation against published known-answer vectors.
  @visibleForTesting
  static String sha256Hex(List<int> message) {
    return _toHex(_sha256(message));
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
