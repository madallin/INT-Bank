import 'package:flutter/foundation.dart';

/// Banking Security: Inactivity Auto-Lock & Ephemeral Session Timeout Guard.
///
/// Drives a deterministic countdown from the last recorded user activity.
/// When the countdown enters the warning window, then reaches zero, the
/// session locks and a privacy veil / re-authentication is required.
/// Time is always derived from the injected [clock]; callers advance state
/// explicitly via [tick] (alias [evaluate]).
enum InactivityLockState { active, warningCountdown, locked, terminated }

/// Result of a re-authentication attempt performed while locked.
class InactivityLockService {
  InactivityLockService({
    DateTime Function() clock = DateTime.now,
    Duration timeout = const Duration(seconds: defaultTimeoutSeconds),
    Duration warningWindow = const Duration(seconds: defaultWarningWindowSeconds),
    Duration lockGracePeriod = const Duration(seconds: 60),
  })  : _clock = clock,
        _timeout = timeout,
        _warningWindow = warningWindow,
        _lockGracePeriod = lockGracePeriod,
        _lastActivityAt = clock();

  /// Default banking inactivity timeout: 300 seconds.
  static const int defaultTimeoutSeconds = 300;

  /// Default warning window before lock: 30 seconds.
  static const int defaultWarningWindowSeconds = 30;

  final DateTime Function() _clock;
  Duration _timeout;
  Duration _warningWindow;
  Duration _lockGracePeriod;

  InactivityLockState _state = InactivityLockState.active;
  DateTime _lastActivityAt;
  DateTime? _lockedAt;
  bool _started = false;

  void Function(Duration remaining)? _onWarning;
  VoidCallback? _onLock;
  VoidCallback? _onTerminate;
  VoidCallback? _onPrivacyVeilRequired;
  VoidCallback? _onReauthenticationRequired;

  /// Configured inactivity timeout.
  Duration get timeout => _timeout;

  /// Configured warning window.
  Duration get warningWindow => _warningWindow;

  /// Configured grace period between lock and termination.
  Duration get lockGracePeriod => _lockGracePeriod;

  /// Current lock lifecycle state.
  InactivityLockState get state => _state;

  /// Timestamp of the last recorded user activity.
  DateTime get lastActivityAt => _lastActivityAt;

  /// Whether the session is active (no warning).
  bool get isActive => _state == InactivityLockState.active;

  /// Whether the session is locked and awaiting re-authentication.
  bool get isLocked => _state == InactivityLockState.locked;

  /// Whether the session has been terminated.
  bool get isTerminated => _state == InactivityLockState.terminated;

  /// Whether the privacy veil must be overlaid.
  bool get shouldShowPrivacyVeil =>
      _state == InactivityLockState.locked || _state == InactivityLockState.terminated;

  /// Whether re-authentication is required to continue.
  bool get requiresReauthentication =>
      _state == InactivityLockState.locked || _state == InactivityLockState.terminated;

  /// Time remaining before lock, based on the injected clock.
  Duration get remaining {
    if (!_started) return _timeout;
    if (_state == InactivityLockState.locked || _state == InactivityLockState.terminated) {
      return Duration.zero;
    }
    final Duration elapsed = _clock().difference(_lastActivityAt);
    final Duration rem = _timeout - elapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Time remaining inside the warning window, or zero when not warning.
  Duration get warningRemaining {
    final Duration rem = remaining;
    if (rem <= Duration.zero) return Duration.zero;
    return rem <= _warningWindow ? rem : Duration.zero;
  }

  /// Starts (or restarts) the countdown and optionally sets callbacks.
  void start({
    void Function(Duration remaining)? onWarning,
    VoidCallback? onLock,
    VoidCallback? onTerminate,
    VoidCallback? onPrivacyVeilRequired,
    VoidCallback? onReauthenticationRequired,
  }) {
    if (onWarning != null) _onWarning = onWarning;
    if (onLock != null) _onLock = onLock;
    if (onTerminate != null) _onTerminate = onTerminate;
    if (onPrivacyVeilRequired != null) _onPrivacyVeilRequired = onPrivacyVeilRequired;
    if (onReauthenticationRequired != null) {
      _onReauthenticationRequired = onReauthenticationRequired;
    }
    _started = true;
    _state = InactivityLockState.active;
    _lastActivityAt = _clock();
    _lockedAt = null;
  }

  void setOnWarning(void Function(Duration remaining) callback) {
    _onWarning = callback;
  }

  void setOnLock(VoidCallback callback) {
    _onLock = callback;
  }

  void setOnTerminate(VoidCallback callback) {
    _onTerminate = callback;
  }

  void setOnPrivacyVeilRequired(VoidCallback callback) {
    _onPrivacyVeilRequired = callback;
  }

  void setOnReauthenticationRequired(VoidCallback callback) {
    _onReauthenticationRequired = callback;
  }

  /// Records a touch interaction and resets the countdown.
  void recordTouch() => recordActivity();

  /// Records a navigation interaction and resets the countdown.
  void recordNavigation() => recordActivity();

  /// Generic activity observer. Resets the countdown to [timeout] and, when
  /// currently warning, returns the state to active. Ignored once locked.
  void recordActivity() {
    if (!_started) return;
    if (_state == InactivityLockState.locked || _state == InactivityLockState.terminated) {
      return;
    }
    _lastActivityAt = _clock();
    _state = InactivityLockState.active;
  }

  /// Recomputes the state from the injected clock and fires transitions once.
  void tick() {
    if (!_started) return;

    final DateTime now = _clock();
    final Duration elapsed = now.difference(_lastActivityAt);
    final Duration rem = _timeout - elapsed;

    if (rem <= Duration.zero) {
      if (_state == InactivityLockState.active ||
          _state == InactivityLockState.warningCountdown) {
        _state = InactivityLockState.locked;
        _lockedAt = now;
        _onLock?.call();
        _onPrivacyVeilRequired?.call();
        _onReauthenticationRequired?.call();
      }
      if (_state == InactivityLockState.locked) {
        final DateTime lockedAt = _lockedAt ?? now;
        if (now.difference(lockedAt) >= _lockGracePeriod) {
          _state = InactivityLockState.terminated;
          _onTerminate?.call();
        }
      }
      return;
    }

    if (rem <= _warningWindow) {
      if (_state != InactivityLockState.warningCountdown) {
        _state = InactivityLockState.warningCountdown;
        _onWarning?.call(rem);
      }
      return;
    }

    if (_state != InactivityLockState.active) {
      _state = InactivityLockState.active;
    }
  }

  /// Alias for [tick].
  void evaluate() => tick();

  /// Attempts to unlock following a re-authentication result.
  /// Returns whether the session was successfully restored.
  bool unlockWithReauthentication(bool authenticated) {
    if (!_started) return false;

    if (authenticated) {
      _state = InactivityLockState.active;
      _lastActivityAt = _clock();
      _lockedAt = null;
      return true;
    }

    final DateTime now = _clock();
    final DateTime? lockedAt = _lockedAt;
    if (lockedAt != null && now.difference(lockedAt) >= _lockGracePeriod) {
      if (_state != InactivityLockState.terminated) {
        _state = InactivityLockState.terminated;
        _onTerminate?.call();
      }
    } else if (_state != InactivityLockState.terminated) {
      _state = InactivityLockState.locked;
    }
    return false;
  }

  /// Explicitly transitions to terminated.
  void terminate() {
    if (_state == InactivityLockState.terminated) return;
    _state = InactivityLockState.terminated;
    _onTerminate?.call();
  }
}
