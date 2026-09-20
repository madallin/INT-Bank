import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Zero-Trust account authorization primitives.
///
/// This library mitigates Broken Object Level Authorization (OWASP API #1,
/// BOLA/IDOR) by verifying that a mutated account belongs to the authenticated
/// user, and it mitigates replay attacks with a bounded timestamp window plus
/// single-use nonces bound into an HMAC-SHA256 signature.

/// Outcome of an ownership or envelope validation step.
///
/// The enum is exhaustive so callers can switch on every possible result.
enum ValidationOutcome {
  /// The claim is owned by the authenticated user and the envelope is valid.
  success(true, 'Request accepted'),

  /// The mutated account is not owned by the authenticated user (BOLA/IDOR).
  ownershipMismatch(false, 'Account ownership mismatch'),

  /// The signed timestamp is older than the accepted validity window.
  expiredTimestamp(false, 'Request timestamp expired'),

  /// The signed timestamp is too far in the future for the injected clock.
  futureTimestamp(false, 'Request timestamp is in the future'),

  /// The nonce was already accepted once and cannot be reused.
  replayedNonce(false, 'Nonce replayed'),

  /// The signature is missing, malformed or does not match the payload.
  invalidSignature(false, 'Signature invalid'),

  /// The envelope is structurally unusable (empty nonce or signature).
  malformedEnvelope(false, 'Security envelope malformed');

  const ValidationOutcome(this.isValid, this.message);

  /// True only for [ValidationOutcome.success].
  final bool isValid;

  /// Human readable, emoji free description of the outcome.
  final String message;

  /// Convenience flag for the success case.
  bool get isSuccess => this == ValidationOutcome.success;
}

/// Immutable description of who is allowed to touch a given account.
///
/// [authenticatedUserId] is the JWT subject resolved client-side.
/// [owningUserId] is the authoritative owner resolved server-side; when it is
/// absent the claim fails closed and is treated as a mismatch.
class AccountOwnershipClaim {
  const AccountOwnershipClaim({
    required this.authenticatedUserId,
    required this.requestedAccountId,
    this.owningUserId,
  });

  /// Identifier of the currently authenticated user.
  final String authenticatedUserId;

  /// Identifier of the account being requested or mutated.
  final String requestedAccountId;

  /// Authoritative owner of [requestedAccountId], if known.
  final String? owningUserId;

  /// True when the server resolved owner matches the authenticated user.
  ///
  /// An unknown owner is not trusted and therefore reported as not owned,
  /// which keeps the check fail-closed under a Zero-Trust model.
  bool get isOwnedByAuthenticatedUser {
    final owner = owningUserId;
    if (owner == null || owner.isEmpty) {
      return false;
    }
    return owner == authenticatedUserId;
  }

  /// Inverse of [isOwnedByAuthenticatedUser], expressed for readability.
  bool get isOwnershipMismatch => !isOwnedByAuthenticatedUser;

  AccountOwnershipClaim copyWith({
    String? authenticatedUserId,
    String? requestedAccountId,
    String? owningUserId,
  }) {
    return AccountOwnershipClaim(
      authenticatedUserId: authenticatedUserId ?? this.authenticatedUserId,
      requestedAccountId: requestedAccountId ?? this.requestedAccountId,
      owningUserId: owningUserId ?? this.owningUserId,
    );
  }
}

/// Immutable cryptographic envelope attached to a request.
///
/// [timestamp] is always normalized to UTC. [signature] is the lowercase hex
/// HMAC-SHA256 authenticator over the canonical payload produced by
/// [AccountSecurityValidator.buildCanonicalPayload].
class HmacSecurityEnvelope {
  const HmacSecurityEnvelope({
    required this.nonce,
    required this.timestamp,
    required this.signature,
    this.keyId,
  });

  /// Single-use random value bound into the signature.
  final String nonce;

  /// UTC time at which the request was signed.
  final DateTime timestamp;

  /// Lowercase hex HMAC-SHA256 over the canonical payload.
  final String signature;

  /// Optional key identifier for key rotation.
  final String? keyId;

  /// UTC normalized timestamp.
  DateTime get timestampUtc => timestamp.toUtc();

  HmacSecurityEnvelope copyWith({
    String? nonce,
    DateTime? timestamp,
    String? signature,
    String? keyId,
  }) {
    return HmacSecurityEnvelope(
      nonce: nonce ?? this.nonce,
      timestamp: timestamp ?? this.timestamp,
      signature: signature ?? this.signature,
      keyId: keyId ?? this.keyId,
    );
  }
}

/// Deterministic, clock-injected Zero-Trust request validator.
///
/// The validator is intentionally free of side effects other than the
/// single-use nonce cache. Inject [clock] and [nonceGenerator] in tests to make
/// every outcome fully deterministic.
class AccountSecurityValidator {
  /// Creates a validator from raw key bytes.
  ///
  /// [clock] defaults to [DateTime.now] and [nonceGenerator] defaults to a
  /// cryptographically secure hex generator. [maxTimestampAge] is the maximum
  /// accepted age of a signed timestamp (default 60 seconds). [futureTolerance]
  /// is the small amount of clock skew allowed into the future (default 5
  /// seconds); anything further ahead is rejected as
  /// [ValidationOutcome.futureTimestamp].
  AccountSecurityValidator({
    required List<int> secretKey,
    DateTime Function()? clock,
    String Function()? nonceGenerator,
    this.maxTimestampAge = const Duration(seconds: 60),
    this.futureTolerance = const Duration(seconds: 5),
  })  : _secretKey = List<int>.unmodifiable(secretKey),
        clock = clock ?? DateTime.now,
        nonceGenerator = nonceGenerator ?? generateSecureNonce {
    if (secretKey.isEmpty) {
      throw ArgumentError.value(secretKey, 'secretKey', 'must not be empty');
    }
  }

  /// Creates a validator from a UTF-8 secret string.
  factory AccountSecurityValidator.fromSecretString({
    required String secret,
    DateTime Function()? clock,
    String Function()? nonceGenerator,
    Duration maxTimestampAge = const Duration(seconds: 60),
    Duration futureTolerance = const Duration(seconds: 5),
  }) {
    return AccountSecurityValidator(
      secretKey: utf8.encode(secret),
      clock: clock,
      nonceGenerator: nonceGenerator,
      maxTimestampAge: maxTimestampAge,
      futureTolerance: futureTolerance,
    );
  }

  final List<int> _secretKey;
  final Set<String> _usedNonces = <String>{};

  /// Injected time source. Never call [DateTime.now] directly in logic.
  final DateTime Function() clock;

  /// Injected nonce source so tests can supply a deterministic sequence.
  final String Function() nonceGenerator;

  /// Maximum accepted age for a signed timestamp before it is rejected.
  final Duration maxTimestampAge;

  /// Maximum accepted clock skew into the future.
  final Duration futureTolerance;

  /// Generates a fresh, cryptographically secure 128-bit hex nonce.
  static String generateSecureNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Returns the next nonce from the injected generator.
  String generateNonce() => nonceGenerator();

  /// Returns the current injected time, normalized to UTC.
  DateTime generateTimestamp() => clock().toUtc();

  /// Number of nonces accepted so far.
  int get usedNonceCount => _usedNonces.length;

  /// Whether [nonce] has already been accepted once.
  bool isNonceUsed(String nonce) => _usedNonces.contains(nonce);

  /// Clears the single-use nonce cache.
  void clearNonceCache() => _usedNonces.clear();

  /// Builds the canonical, stably ordered signature material.
  ///
  /// Fields are emitted in a fixed alphabetical order and joined with `&` so
  /// the payload is independent of insertion order:
  /// `accountId=..&keyId=..&nonce=..&timestamp=..&userId=..`.
  String buildCanonicalPayload({
    required String authenticatedUserId,
    required String requestedAccountId,
    required String nonce,
    required DateTime timestamp,
    String? keyId,
  }) {
    return <String>[
      'accountId=$requestedAccountId',
      'keyId=${keyId ?? ''}',
      'nonce=$nonce',
      'timestamp=${timestamp.toUtc().toIso8601String()}',
      'userId=$authenticatedUserId',
    ].join('&');
  }

  /// Builds the canonical payload for a claim and envelope pair.
  String buildEnvelopePayload(
    AccountOwnershipClaim claim,
    HmacSecurityEnvelope envelope,
  ) {
    return buildCanonicalPayload(
      authenticatedUserId: claim.authenticatedUserId,
      requestedAccountId: claim.requestedAccountId,
      nonce: envelope.nonce,
      timestamp: envelope.timestamp,
      keyId: envelope.keyId,
    );
  }

  /// Computes the lowercase hex HMAC-SHA256 of [canonicalPayload].
  String computeSignature(String canonicalPayload) {
    final hmac = Hmac(sha256, _secretKey);
    return hmac.convert(utf8.encode(canonicalPayload)).toString();
  }

  /// Computes the signature for a claim and envelope pair.
  String computeEnvelopeSignature(
    AccountOwnershipClaim claim,
    HmacSecurityEnvelope envelope,
  ) {
    return computeSignature(buildEnvelopePayload(claim, envelope));
  }

  /// Constant-time comparison of an expected and supplied signature.
  bool verifySignature(String canonicalPayload, String signature) {
    return _constantTimeEquals(computeSignature(canonicalPayload), signature);
  }

  /// Checks only the ownership claim, rejecting BOLA/IDOR mismatches.
  ValidationOutcome validateOwnership(AccountOwnershipClaim claim) {
    return claim.isOwnedByAuthenticatedUser
        ? ValidationOutcome.success
        : ValidationOutcome.ownershipMismatch;
  }

  /// Creates a fully signed envelope for [claim] using injected clock/nonce.
  HmacSecurityEnvelope createEnvelope(
    AccountOwnershipClaim claim, {
    String? keyId,
  }) {
    final timestamp = clock().toUtc();
    final nonce = generateNonce();
    final payload = buildCanonicalPayload(
      authenticatedUserId: claim.authenticatedUserId,
      requestedAccountId: claim.requestedAccountId,
      nonce: nonce,
      timestamp: timestamp,
      keyId: keyId,
    );
    return HmacSecurityEnvelope(
      nonce: nonce,
      timestamp: timestamp,
      signature: computeSignature(payload),
      keyId: keyId,
    );
  }

  /// Validates [envelope] against [claim] before transmission or on receipt.
  ///
  /// Order of checks: ownership, signature integrity, timestamp window, then
  /// nonce replay. The nonce is recorded only after every check succeeds, so a
  /// rejected request never consumes a nonce.
  ValidationOutcome validateEnvelope(
    AccountOwnershipClaim claim,
    HmacSecurityEnvelope envelope,
  ) {
    if (!claim.isOwnedByAuthenticatedUser) {
      return ValidationOutcome.ownershipMismatch;
    }
    if (envelope.nonce.isEmpty || envelope.signature.isEmpty) {
      return ValidationOutcome.malformedEnvelope;
    }
    final expected = computeEnvelopeSignature(claim, envelope);
    if (!_constantTimeEquals(expected, envelope.signature)) {
      return ValidationOutcome.invalidSignature;
    }
    final now = clock().toUtc();
    final timestamp = envelope.timestampUtc;
    final age = now.difference(timestamp);
    if (age > maxTimestampAge) {
      return ValidationOutcome.expiredTimestamp;
    }
    if (age < -futureTolerance) {
      return ValidationOutcome.futureTimestamp;
    }
    if (_usedNonces.contains(envelope.nonce)) {
      return ValidationOutcome.replayedNonce;
    }
    _usedNonces.add(envelope.nonce);
    return ValidationOutcome.success;
  }

  bool _constantTimeEquals(String a, String b) {
    final aUnits = utf8.encode(a);
    final bUnits = utf8.encode(b);
    if (aUnits.length != bUnits.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < aUnits.length; i++) {
      diff |= aUnits[i] ^ bUnits[i];
    }
    return diff == 0;
  }
}
