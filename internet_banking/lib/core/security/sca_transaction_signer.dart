import 'dart:convert';

import 'package:crypto/crypto.dart';

/// PSD2 Article 97 Dynamic Linking: Outcome of a transaction authorization.
enum ScaStatus { approved, rejected, expired, tampered }

/// Immutable challenge binding an authentication code to a specific
/// recipient, amount (in minor units) and currency for a given user.
class ScaChallenge {
  const ScaChallenge({
    required this.challengeId,
    required this.userId,
    required this.recipientIban,
    required this.amountInMinorUnits,
    required this.currency,
    required this.createdAt,
    required this.expiresAt,
    required this.authenticationCode,
    required this.isNewBeneficiary,
  });

  final String challengeId;
  final String userId;
  final String recipientIban;
  final int amountInMinorUnits;
  final String currency;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String authenticationCode;
  final bool isNewBeneficiary;

  ScaChallenge copyWith({
    String? challengeId,
    String? userId,
    String? recipientIban,
    int? amountInMinorUnits,
    String? currency,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? authenticationCode,
    bool? isNewBeneficiary,
  }) {
    return ScaChallenge(
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      recipientIban: recipientIban ?? this.recipientIban,
      amountInMinorUnits: amountInMinorUnits ?? this.amountInMinorUnits,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      authenticationCode: authenticationCode ?? this.authenticationCode,
      isNewBeneficiary: isNewBeneficiary ?? this.isNewBeneficiary,
    );
  }
}

/// Result of verifying or authorizing an [ScaChallenge].
class ScaAuthorizationResult {
  const ScaAuthorizationResult._({
    required this.status,
    required this.valid,
    required this.reason,
    this.challengeId,
  });

  const ScaAuthorizationResult.approved({
    String? challengeId,
    String reason = 'Dynamic linking signature valid',
  }) : this._(
          status: ScaStatus.approved,
          valid: true,
          reason: reason,
          challengeId: challengeId,
        );

  const ScaAuthorizationResult.rejected({
    String? challengeId,
    String reason = 'Authorization rejected by user',
  }) : this._(
          status: ScaStatus.rejected,
          valid: false,
          reason: reason,
          challengeId: challengeId,
        );

  const ScaAuthorizationResult.expired({
    String? challengeId,
    String reason = 'Challenge expired',
  }) : this._(
          status: ScaStatus.expired,
          valid: false,
          reason: reason,
          challengeId: challengeId,
        );

  const ScaAuthorizationResult.tampered({
    String? challengeId,
    String reason = 'Dynamic linking binding mismatch',
  }) : this._(
          status: ScaStatus.tampered,
          valid: false,
          reason: reason,
          challengeId: challengeId,
        );

  final ScaStatus status;
  final String? challengeId;
  final bool valid;
  final String reason;

  bool get isApproved => status == ScaStatus.approved;
  bool get isRejected => status == ScaStatus.rejected;
  bool get isExpired => status == ScaStatus.expired;
  bool get isTampered => status == ScaStatus.tampered;
}

/// PSD2 Article 97 dynamic linking and transaction signing engine.
///
/// Binds an HMAC-SHA256 authentication code to the recipient IBAN, the exact
/// amount in minor units and the currency, so any modification of the
/// presented transaction data invalidates the signature.
class ScaTransactionSigner {
  ScaTransactionSigner({
    required List<int> secretKey,
    required this.clock,
    this.challengeTtl = const Duration(minutes: 5),
  }) : _secretKey = List<int>.unmodifiable(secretKey);

  /// Threshold above which dynamic linking is mandatory (30 EUR in cents).
  static const int dynamicLinkingThresholdMinorUnits = 3000;

  final List<int> _secretKey;

  /// Injected time source. Never call DateTime.now() directly in logic.
  final DateTime Function() clock;

  final Duration challengeTtl;

  /// Returns true when the transaction must be dynamically linked.
  bool requiresDynamicLinking(int amountInMinorUnits,
      {bool isNewBeneficiary = false}) {
    return amountInMinorUnits > dynamicLinkingThresholdMinorUnits ||
        isNewBeneficiary;
  }

  /// Normalizes an IBAN for binding: strips whitespace and uppercases.
  String normalizeIban(String iban) {
    return iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  /// Builds the canonical payload bound by the authentication code.
  String buildCanonicalPayload({
    required String challengeId,
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
  }) {
    return '$challengeId|${normalizeIban(recipientIban)}|'
        '$amountInMinorUnits|$currency';
  }

  /// Computes the HMAC-SHA256 hex authentication code over the canonical
  /// payload for the supplied transaction values.
  String computeAuthenticationCode({
    required String challengeId,
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
  }) {
    final payload = buildCanonicalPayload(
      challengeId: challengeId,
      recipientIban: recipientIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
    );
    final hmac = Hmac(sha256, _secretKey);
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Creates a challenge bound to the given transaction values.
  ScaChallenge createChallenge({
    required String userId,
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
    bool isNewBeneficiary = false,
  }) {
    final now = clock();
    final normalizedIban = normalizeIban(recipientIban);
    final challengeId = _generateChallengeId(
      userId: userId,
      recipientIban: normalizedIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
      createdAt: now,
    );
    final authenticationCode = computeAuthenticationCode(
      challengeId: challengeId,
      recipientIban: normalizedIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
    );
    return ScaChallenge(
      challengeId: challengeId,
      userId: userId,
      recipientIban: normalizedIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
      createdAt: now,
      expiresAt: now.add(challengeTtl),
      authenticationCode: authenticationCode,
      isNewBeneficiary: isNewBeneficiary,
    );
  }

  /// Verifies that the presented transaction data matches the challenge
  /// binding and has not expired.
  ScaAuthorizationResult verifyAuthorization(
    ScaChallenge challenge, {
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
  }) {
    final recomputed = computeAuthenticationCode(
      challengeId: challenge.challengeId,
      recipientIban: recipientIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
    );
    if (!_constantTimeEquals(recomputed, challenge.authenticationCode)) {
      return ScaAuthorizationResult.tampered(
        challengeId: challenge.challengeId,
        reason: 'Dynamic linking binding mismatch: recipient, amount or '
            'currency differs from the signed challenge',
      );
    }
    if (clock().isAfter(challenge.expiresAt)) {
      return ScaAuthorizationResult.expired(
        challengeId: challenge.challengeId,
        reason: 'Challenge expired at ${challenge.expiresAt.toUtc().toIso8601String()}',
      );
    }
    return ScaAuthorizationResult.approved(
      challengeId: challenge.challengeId,
      reason: 'Dynamic linking signature valid and challenge not expired',
    );
  }

  /// Applies the user decision, then verifies the transaction binding.
  ScaAuthorizationResult authorize(
    ScaChallenge challenge, {
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
    bool userApproved = true,
  }) {
    if (!userApproved) {
      return ScaAuthorizationResult.rejected(
        challengeId: challenge.challengeId,
        reason: 'Authorization rejected by user',
      );
    }
    return verifyAuthorization(
      challenge,
      recipientIban: recipientIban,
      amountInMinorUnits: amountInMinorUnits,
      currency: currency,
    );
  }

  String _generateChallengeId({
    required String userId,
    required String recipientIban,
    required int amountInMinorUnits,
    required String currency,
    required DateTime createdAt,
  }) {
    final material = '$userId|$recipientIban|$amountInMinorUnits|$currency|'
        '${createdAt.toUtc().millisecondsSinceEpoch}';
    final digest = sha256.convert(utf8.encode(material)).toString();
    return digest.substring(0, 32);
  }

  bool _constantTimeEquals(String a, String b) {
    final aUnits = utf8.encode(a);
    final bUnits = utf8.encode(b);
    if (aUnits.length != bUnits.length) return false;
    var diff = 0;
    for (var i = 0; i < aUnits.length; i++) {
      diff |= aUnits[i] ^ bUnits[i];
    }
    return diff == 0;
  }
}
