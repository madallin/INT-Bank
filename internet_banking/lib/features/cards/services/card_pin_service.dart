import 'package:flutter/foundation.dart';

/// Outcome of a card PIN change request.
enum PinChangeResult { success, weakPin, pinMismatch, blocked }

/// Reason a card PIN reveal request did not produce a visible PIN.
enum PinRevealFailure { biometricRequired, biometricFailed, tooManyAttempts }

/// Immutable snapshot of an ephemeral, auto-concealing PIN reveal.
///
/// A state is *visible* only while [pin] is non-null and the supplied clock is
/// strictly before [expiresAt]. Once the window elapses the PIN must be cleared
/// via [CardPinService.concealIfExpired].
@immutable
class PinRevealState {
  /// The revealed PIN, or null when the PIN is concealed.
  final String? pin;

  /// Instant at which the PIN was revealed.
  final DateTime revealedAt;

  /// Instant at which the PIN stops being visible (exclusive boundary).
  final DateTime expiresAt;

  const PinRevealState({
    required this.pin,
    required this.revealedAt,
    required this.expiresAt,
  });

  /// True when [pin] is present and [now] is strictly before [expiresAt].
  bool isVisibleAt(DateTime now) {
    return pin != null && now.isBefore(expiresAt);
  }

  /// Masked representation: four asterisks while a PIN is present, otherwise
  /// an empty string once the PIN has been concealed.
  String get maskedPin => pin == null ? '' : '****';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PinRevealState &&
        other.pin == pin &&
        other.revealedAt == revealedAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(pin, revealedAt, expiresAt);

  @override
  String toString() => 'PinRevealState(maskedPin: $maskedPin, '
      'revealedAt: $revealedAt, expiresAt: $expiresAt)';
}

/// Immutable result of a PIN reveal attempt.
///
/// Exactly one of [state] and [failure] is non-null in normal use.
@immutable
class PinRevealResult {
  /// The revealed state when the attempt succeeded, otherwise null.
  final PinRevealState? state;

  /// The failure reason when the attempt failed, otherwise null.
  final PinRevealFailure? failure;

  const PinRevealResult({this.state, this.failure});

  /// Convenience constructor for a successful reveal.
  const PinRevealResult.success(PinRevealState this.state) : failure = null;

  /// Convenience constructor for a failed reveal.
  const PinRevealResult.failure(PinRevealFailure this.failure) : state = null;

  /// True when the attempt produced a visible PIN state.
  bool get isSuccess => state != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PinRevealResult &&
        other.state == state &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(state, failure);

  @override
  String toString() => 'PinRevealResult(state: $state, failure: $failure)';
}

/// Domain service for securely revealing and changing a card PIN.
///
/// Reveal requires biometric verification and produces an ephemeral state that
/// clears after [revealWindowSeconds]. All time dependent operations accept the
/// current time explicitly so behaviour is fully deterministic in tests; no
/// wall clock is ever read and no timers are used.
class CardPinService {
  /// Length of the ephemeral reveal window in seconds.
  static const int revealWindowSeconds = 10;

  /// Maximum number of failed biometric attempts before reveal is locked.
  static const int maxBiometricAttempts = 3;

  /// Trivial or widely used PINs that are always rejected.
  static const Set<String> _blocklist = <String>{
    '0000',
    '1111',
    '2222',
    '1234',
    '4321',
    '1212',
    '0101',
    '1122',
    '6969',
    '1010',
  };

  String _storedPin;
  int _failedBiometricAttempts = 0;

  /// Creates a service backed by [initialPin].
  CardPinService({String initialPin = '5839'}) : _storedPin = initialPin;

  /// The currently stored PIN. Exposed for test assertions only.
  @visibleForTesting
  String get storedPin => _storedPin;

  /// Returns true when [pin] is too weak to be accepted.
  ///
  /// Rejected inputs are: anything that is not exactly four digits, any PIN
  /// made of a single repeated digit, any strictly ascending or descending
  /// consecutive sequence, and any entry on the common PIN blocklist.
  bool isWeakPin(String pin) {
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      return true;
    }
    if (_blocklist.contains(pin)) {
      return true;
    }
    final List<int> digits =
        pin.codeUnits.map((int unit) => unit - 0x30).toList();
    final bool allSame = digits.every((int digit) => digit == digits.first);
    if (allSame) {
      return true;
    }
    bool ascending = true;
    bool descending = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) {
        ascending = false;
      }
      if (digits[i] != digits[i - 1] - 1) {
        descending = false;
      }
    }
    return ascending || descending;
  }

  /// Attempts to change the stored PIN.
  ///
  /// Returns [PinChangeResult.blocked] when [biometricVerified] is false,
  /// [PinChangeResult.pinMismatch] when [newPin] differs from [confirmPin],
  /// [PinChangeResult.weakPin] when [newPin] fails [isWeakPin], and otherwise
  /// [PinChangeResult.success] while mutating the stored PIN. Failed attempts
  /// never mutate the stored PIN.
  PinChangeResult changePin({
    required String oldPin,
    required String newPin,
    required String confirmPin,
    required bool biometricVerified,
  }) {
    if (!biometricVerified) {
      return PinChangeResult.blocked;
    }
    if (newPin != confirmPin) {
      return PinChangeResult.pinMismatch;
    }
    if (isWeakPin(newPin)) {
      return PinChangeResult.weakPin;
    }
    _storedPin = newPin;
    return PinChangeResult.success;
  }

  /// Attempts to reveal the stored PIN after a biometric challenge.
  ///
  /// A false [biometricVerified] first yields
  /// [PinRevealFailure.biometricRequired], then
  /// [PinRevealFailure.biometricFailed] for subsequent within-limit failures,
  /// and finally [PinRevealFailure.tooManyAttempts] once
  /// [maxBiometricAttempts] failures have been recorded. A successful reveal
  /// resets the failure counter and produces a state expiring
  /// [revealWindowSeconds] after [now].
  PinRevealResult revealPin({
    required bool biometricVerified,
    required DateTime now,
  }) {
    if (!biometricVerified) {
      if (_failedBiometricAttempts >= maxBiometricAttempts) {
        return const PinRevealResult.failure(PinRevealFailure.tooManyAttempts);
      }
      _failedBiometricAttempts++;
      if (_failedBiometricAttempts == 1) {
        return const PinRevealResult.failure(PinRevealFailure.biometricRequired);
      }
      return const PinRevealResult.failure(PinRevealFailure.biometricFailed);
    }
    _failedBiometricAttempts = 0;
    return PinRevealResult.success(
      PinRevealState(
        pin: _storedPin,
        revealedAt: now,
        expiresAt: now.add(const Duration(seconds: revealWindowSeconds)),
      ),
    );
  }

  /// Returns a concealed copy of [state] with the PIN removed from memory.
  PinRevealState conceal(PinRevealState state) {
    if (state.pin == null) {
      return state;
    }
    return PinRevealState(
      pin: null,
      revealedAt: state.revealedAt,
      expiresAt: state.expiresAt,
    );
  }

  /// Conceals [state] when it is no longer visible at [now].
  ///
  /// Returns the same instance while the reveal window is still open, and a
  /// concealed state (with a null PIN) at or after [PinRevealState.expiresAt].
  PinRevealState concealIfExpired(PinRevealState state, DateTime now) {
    if (state.isVisibleAt(now)) {
      return state;
    }
    return conceal(state);
  }
}
