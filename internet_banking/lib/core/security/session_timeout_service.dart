import 'dart:async';
import 'package:flutter/widgets.dart';

/// Banking Security Service: Inactivity & Background Session Timeout
///
/// Automatically tracks user inactivity and app lifecycle changes (paused/inactive vs resumed).
/// If the user remains idle or the app remains in the background for >= 3 minutes (180 seconds),
/// the registered logout/lock callback is executed to secure customer banking data.
class SessionTimeoutService with WidgetsBindingObserver {
  static final SessionTimeoutService instance = SessionTimeoutService._internal();
  factory SessionTimeoutService() => instance;

  @visibleForTesting
  SessionTimeoutService.test({
    Duration timeout = defaultTimeout,
    this.onTimeout,
  }) : _timeout = timeout {
    _lastActivityTime = DateTime.now();
  }

  SessionTimeoutService._internal() {
    _lastActivityTime = DateTime.now();
  }

  /// Default banking inactivity timeout: 3 minutes (180 seconds)
  static const Duration defaultTimeout = Duration(minutes: 3);
  static const int defaultTimeoutSeconds = 180;

  Duration _timeout = defaultTimeout;
  VoidCallback? onTimeout;

  Timer? _timer;
  DateTime _lastActivityTime = DateTime.now();
  DateTime? _backgroundTime;
  bool _isStarted = false;
  bool _isLocked = false;
  bool _isBackgrounded = false;
  bool _observerRegistered = false;

  /// Returns the configured session timeout duration.
  Duration get timeout => _timeout;

  /// Returns the timestamp of the last recorded user activity.
  DateTime get lastActivityTime => _lastActivityTime;

  /// Returns the timestamp when the app went to the background, if currently backgrounded.
  DateTime? get backgroundTime => _backgroundTime;

  /// Whether the session timeout tracking is actively running.
  bool get isRunning => _isStarted && !_isLocked;

  /// Whether the session has timed out and locked.
  bool get isLocked => _isLocked;

  /// Whether the app is currently detected as backgrounded.
  bool get isBackgrounded => _isBackgrounded;

  /// Remaining duration before the session times out.
  Duration get remainingTime {
    if (!_isStarted || _isLocked) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastActivityTime);
    final remaining = _timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Starts the inactivity session timer and registers lifecycle observation.
  void start({
    VoidCallback? onTimeout,
    Duration? timeout,
  }) {
    if (onTimeout != null) {
      this.onTimeout = onTimeout;
    }
    if (timeout != null) {
      _timeout = timeout;
    }
    _isStarted = true;
    _isLocked = false;
    _isBackgrounded = false;
    _backgroundTime = null;
    _lastActivityTime = DateTime.now();

    _registerObserver();
    _startTimer(_timeout);
  }

  /// Initializes the service alias for start.
  void initialize({
    VoidCallback? onTimeout,
    Duration? timeout,
  }) =>
      start(onTimeout: onTimeout, timeout: timeout);

  /// Updates or sets the logout/lock callback.
  void setOnTimeout(VoidCallback callback) {
    onTimeout = callback;
  }

  /// Resets the inactivity timer when the user interacts with the app
  /// (e.g. tap, scroll, key input, navigation).
  void recordUserActivity() {
    if (!_isStarted || _isLocked) return;
    _lastActivityTime = DateTime.now();
    if (!_isBackgrounded) {
      _startTimer(_timeout);
    }
  }

  /// Alias for [recordUserActivity].
  void resetTimer() => recordUserActivity();

  /// Alias for [recordUserActivity].
  void recordInteraction() => recordUserActivity();

  /// Manually triggers session lock/logout.
  void lockSession() {
    if (_isLocked) return;
    _isLocked = true;
    _timer?.cancel();
    _timer = null;
    onTimeout?.call();
  }

  /// Unlocks or restarts the session timer after successful re-authentication.
  void unlockSession() {
    _isLocked = false;
    _lastActivityTime = DateTime.now();
    _backgroundTime = null;
    if (_isStarted) {
      _startTimer(_timeout);
    }
  }

  /// Stops and pauses the timer without clearing configuration.
  void stop() {
    _isStarted = false;
    _timer?.cancel();
    _timer = null;
    _unregisterObserver();
  }

  /// Completely disposes of timer and unregisters observer.
  void dispose() {
    stop();
    onTimeout = null;
    _isLocked = false;
    _isBackgrounded = false;
    _backgroundTime = null;
  }

  void _registerObserver() {
    if (_observerRegistered) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    } catch (_) {
      // Binding not initialized in pure unit test environment
    }
  }

  void _unregisterObserver() {
    if (!_observerRegistered) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    } catch (_) {
      // Binding not initialized
    }
  }

  void _startTimer(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, _handleTimeout);
  }

  void _handleTimeout() {
    if (!_isStarted || _isLocked) return;
    final elapsed = DateTime.now().difference(_lastActivityTime);
    if (elapsed >= _timeout) {
      lockSession();
    } else {
      // User may have interacted slightly before timer expired
      _startTimer(_timeout - elapsed);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (!_isBackgrounded) {
          _isBackgrounded = true;
          _backgroundTime = DateTime.now();
          _timer?.cancel();
          _timer = null;
        }
        break;

      case AppLifecycleState.resumed:
        final wasBackgrounded = _isBackgrounded;
        _isBackgrounded = false;

        if (!_isStarted || _isLocked) {
          _backgroundTime = null;
          return;
        }

        if (wasBackgrounded) {
          final now = DateTime.now();
          final elapsed = now.difference(_lastActivityTime);

          if (elapsed >= _timeout) {
            // Idle for >= 180 seconds across backgrounding
            lockSession();
          } else {
            // Re-schedule for remaining time
            _startTimer(_timeout - elapsed);
          }
          _backgroundTime = null;
        }
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
