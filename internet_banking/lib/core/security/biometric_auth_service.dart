import 'package:flutter/foundation.dart';

/// The category of biometric hardware exposed by the platform.
enum BiometricHardwareType { none, fingerprint, face, iris, multiple }

/// The outcome of a biometric authentication attempt.
enum BiometricAuthStatus { success, canceled, lockedOut, notAvailable, failed }

/// Banking Security Model: Biometric Hardware Capability
///
/// Encapsulates whether biometric hardware is present, whether at least one
/// credential is enrolled, and which biometric modalities are supported.
@immutable
class BiometricCapability {
  const BiometricCapability({
    required this.hardwareType,
    required this.isAvailable,
    required this.isEnrolled,
    this.supportedTypes = const <BiometricHardwareType>[],
  });

  /// The primary biometric hardware category reported by the platform.
  final BiometricHardwareType hardwareType;

  /// Whether biometric hardware is physically present on the device.
  final bool isAvailable;

  /// Whether at least one biometric credential has been enrolled.
  final bool isEnrolled;

  /// The full list of biometric modalities supported by the device.
  final List<BiometricHardwareType> supportedTypes;

  /// Whether biometric authentication can be performed right now.
  bool get isReady =>
      isAvailable &&
      isEnrolled &&
      hardwareType != BiometricHardwareType.none;

  /// Creates a copy with the provided fields replaced.
  BiometricCapability copyWith({
    BiometricHardwareType? hardwareType,
    bool? isAvailable,
    bool? isEnrolled,
    List<BiometricHardwareType>? supportedTypes,
  }) {
    return BiometricCapability(
      hardwareType: hardwareType ?? this.hardwareType,
      isAvailable: isAvailable ?? this.isAvailable,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      supportedTypes: supportedTypes ?? this.supportedTypes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BiometricCapability &&
        other.hardwareType == hardwareType &&
        other.isAvailable == isAvailable &&
        other.isEnrolled == isEnrolled &&
        listEquals(other.supportedTypes, supportedTypes);
  }

  @override
  int get hashCode => Object.hash(
        hardwareType,
        isAvailable,
        isEnrolled,
        Object.hashAll(supportedTypes),
      );

  @override
  String toString() => 'BiometricCapability(hardwareType: $hardwareType, '
      'isAvailable: $isAvailable, isEnrolled: $isEnrolled, '
      'supportedTypes: $supportedTypes)';
}

/// Banking Security Model: Biometric Challenge Signature
///
/// Carries the hardware signature, its timestamp, the originating challenge
/// nonce, and the anti-replay session token issued by the service.
@immutable
class BiometricSignatureResult {
  const BiometricSignatureResult({
    required this.signature,
    required this.timestamp,
    required this.nonce,
    required this.authenticatedToken,
  });

  /// The hardware generated signature for the challenge.
  final String signature;

  /// The moment at which the signature was produced.
  final DateTime timestamp;

  /// The challenge nonce that was signed.
  final String nonce;

  /// The session token issued in exchange for a valid signature.
  final String authenticatedToken;

  /// Creates a copy with the provided fields replaced.
  BiometricSignatureResult copyWith({
    String? signature,
    DateTime? timestamp,
    String? nonce,
    String? authenticatedToken,
  }) {
    return BiometricSignatureResult(
      signature: signature ?? this.signature,
      timestamp: timestamp ?? this.timestamp,
      nonce: nonce ?? this.nonce,
      authenticatedToken: authenticatedToken ?? this.authenticatedToken,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BiometricSignatureResult &&
        other.signature == signature &&
        other.timestamp == timestamp &&
        other.nonce == nonce &&
        other.authenticatedToken == authenticatedToken;
  }

  @override
  int get hashCode =>
      Object.hash(signature, timestamp, nonce, authenticatedToken);

  @override
  String toString() => 'BiometricSignatureResult(signature: $signature, '
      'timestamp: $timestamp, nonce: $nonce, '
      'authenticatedToken: $authenticatedToken)';
}

/// Platform adapter interface for biometric hardware.
///
/// Implementations bridge to FaceID, TouchID, or Android BiometricPrompt
/// (Class 3 Strong). All hardware access is routed through this contract so
/// that the service remains pure Dart and fully unit testable.
abstract class BiometricHardwareGateway {
  /// Reports the current biometric hardware capability of the device.
  Future<BiometricCapability> getCapability();

  /// Prompts the user for biometric authentication using [reason].
  Future<bool> authenticate({required String reason});

  /// Requests a hardware signature over [challengeNonce] at [timestamp].
  Future<BiometricSignatureResult> signChallenge({
    required String challengeNonce,
    required DateTime timestamp,
  });
}

/// Banking Security Service: Biometric Authentication Engine
///
/// Manages hardware capability discovery, challenge-nonce signing, anti-replay
/// session tokens, and lockout with exponential backoff. All time reads are
/// routed through an injected clock so behavior is fully deterministic.
class BiometricAuthService {
  BiometricAuthService({
    required BiometricHardwareGateway gateway,
    DateTime Function()? clock,
    this.maxFailedAttempts = 5,
    this.baseLockoutDuration = const Duration(seconds: 30),
    this.maxLockoutDuration = const Duration(minutes: 15),
    this.maxChallengeAge = const Duration(minutes: 1),
    this.sessionTokenTtl = const Duration(minutes: 5),
  })  : _gateway = gateway,
        _clock = clock ?? DateTime.now;

  /// Default user facing authentication reason.
  static const String defaultReason =
      'Authenticate to access your account';

  /// Service held secret mixed into deterministic session tokens.
  static const String _tokenSecret = 'intbank-biometric-session-token-v1';

  final BiometricHardwareGateway _gateway;
  final DateTime Function() _clock;

  /// Number of consecutive failures before a lockout episode is entered.
  final int maxFailedAttempts;

  /// Base duration of the first lockout episode.
  final Duration baseLockoutDuration;

  /// Upper bound applied to exponentially growing lockout durations.
  final Duration maxLockoutDuration;

  /// Maximum accepted age of a signed challenge.
  final Duration maxChallengeAge;

  /// Lifetime associated with generated session tokens.
  final Duration sessionTokenTtl;

  BiometricCapability? _cachedCapability;
  int _failedAttempts = 0;
  int _lockoutCount = 0;
  DateTime? _lockoutUntil;

  /// Number of consecutive failed authentication attempts.
  int get failedAttempts => _failedAttempts;

  /// Number of lockout episodes entered without an intervening success.
  int get lockoutCount => _lockoutCount;

  /// The instant until which authentication remains locked out, if any.
  DateTime? get lockoutUntil => _lockoutUntil;

  /// The current service time as reported by the injected clock.
  DateTime get now => _clock();

  /// Whether authentication is currently blocked by an active lockout.
  bool get isLockedOut {
    final until = _lockoutUntil;
    if (until == null) return false;
    return now.isBefore(until);
  }

  /// Time remaining in the active lockout, or [Duration.zero] when unlocked.
  Duration get remainingLockout {
    final until = _lockoutUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns the biometric capability, consulting hardware only on first use.
  Future<BiometricCapability> evaluateCapability() async {
    final cached = _cachedCapability;
    if (cached != null) return cached;
    final capability = await _gateway.getCapability();
    _cachedCapability = capability;
    return capability;
  }

  /// Performs a biometric authentication prompt.
  ///
  /// Returns [BiometricAuthStatus.notAvailable] without touching hardware when
  /// the capability is not ready, [BiometricAuthStatus.lockedOut] while a
  /// lockout is active, and maps the gateway boolean to success or canceled.
  /// Gateway errors map to [BiometricAuthStatus.failed]. Success resets the
  /// failure and lockout counters, while failures advance the lockout state.
  Future<BiometricAuthStatus> authenticate({String reason = defaultReason}) async {
    if (isLockedOut) return BiometricAuthStatus.lockedOut;

    final capability = await evaluateCapability();
    if (!capability.isReady) return BiometricAuthStatus.notAvailable;

    bool authenticated;
    try {
      authenticated = await _gateway.authenticate(reason: reason);
    } catch (_) {
      _registerFailure();
      return isLockedOut
          ? BiometricAuthStatus.lockedOut
          : BiometricAuthStatus.failed;
    }

    if (authenticated) {
      _resetFailures();
      return BiometricAuthStatus.success;
    }

    _registerFailure();
    return isLockedOut
        ? BiometricAuthStatus.lockedOut
        : BiometricAuthStatus.canceled;
  }

  /// Signs [challengeNonce] with the hardware and issues a session token.
  ///
  /// Throws [StateError] when the service is locked out, hardware is not
  /// ready, the gateway fails, the returned nonce does not match the challenge,
  /// or the returned timestamp is not fresh according to the injected clock.
  Future<BiometricSignatureResult> authenticateWithChallenge({
    required String challengeNonce,
  }) async {
    if (isLockedOut) {
      throw StateError('Biometric authentication is locked out.');
    }

    final capability = await evaluateCapability();
    if (!capability.isReady) {
      throw StateError('Biometric hardware is not available.');
    }

    final issuedAt = now;
    BiometricSignatureResult signature;
    try {
      signature = await _gateway.signChallenge(
        challengeNonce: challengeNonce,
        timestamp: issuedAt,
      );
    } catch (_) {
      _registerFailure();
      throw StateError('Biometric challenge signing failed.');
    }

    if (signature.nonce != challengeNonce) {
      _registerFailure();
      throw StateError('Biometric challenge nonce mismatch.');
    }

    if (!isChallengeFresh(signature.timestamp)) {
      _registerFailure();
      throw StateError('Biometric challenge has expired.');
    }

    final token = generateSessionToken(
      nonce: signature.nonce,
      issuedAt: signature.timestamp,
    );
    _resetFailures();

    return BiometricSignatureResult(
      signature: signature.signature,
      timestamp: signature.timestamp,
      nonce: signature.nonce,
      authenticatedToken: token,
    );
  }

  /// Whether [issuedAt] is neither in the future nor older than
  /// [maxChallengeAge] relative to the injected clock.
  bool isChallengeFresh(DateTime issuedAt) {
    final age = now.difference(issuedAt);
    if (age.isNegative) return false;
    return age <= maxChallengeAge;
  }

  /// Generates a deterministic session token from [nonce] and [issuedAt].
  ///
  /// The token is a pure hash of the challenge material and a service held
  /// secret; no randomness is involved.
  String generateSessionToken({
    required String nonce,
    required DateTime issuedAt,
  }) {
    final payload = '$_tokenSecret|$nonce|'
        '${issuedAt.microsecondsSinceEpoch}|${sessionTokenTtl.inMicroseconds}';
    return _hashHex(payload);
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts < maxFailedAttempts) return;

    _lockoutCount++;
    final duration = _computeLockoutDuration();
    _lockoutUntil = now.add(duration);
  }

  Duration _computeLockoutDuration() {
    var duration = baseLockoutDuration;
    for (var i = 1; i < _lockoutCount && duration < maxLockoutDuration; i++) {
      duration *= 2;
    }
    return duration > maxLockoutDuration ? maxLockoutDuration : duration;
  }

  void _resetFailures() {
    _failedAttempts = 0;
    _lockoutCount = 0;
    _lockoutUntil = null;
  }

  static String _hashHex(String input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (final unit in input.codeUnits) {
      h1 ^= unit & 0xFF;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h1 ^= (unit >> 8) & 0xFF;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;

      h2 = (h2 + unit) & 0xFFFFFFFF;
      h2 = (h2 ^ (h2 >> 15)) & 0xFFFFFFFF;
      h2 = (h2 * 0x85ebca6b) & 0xFFFFFFFF;
      h2 = (h2 ^ (h2 >> 13)) & 0xFFFFFFFF;
    }
    final first = h1.toRadixString(16).padLeft(8, '0');
    final second = h2.toRadixString(16).padLeft(8, '0');
    return '$first$second';
  }
}
