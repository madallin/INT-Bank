/// Anti-Tamper Screen Protection & Privacy Veil Lifecycle Controller.
///
/// Controls native window secure flags and the App Switcher privacy veil for
/// sensitive banking UI. This file intentionally declares its own local
/// [AppLifecycleState] enum so the service can be unit tested without importing
/// `dart:ui` (which exports a conflicting enum of the same name).
library;

/// Local mirror of the Flutter app lifecycle states used by this service.
enum AppLifecycleState { resumed, inactive, paused, detached, hidden }

/// Screen protection strictness applied by [ScreenProtectionService].
enum ScreenProtectionPolicy {
  /// No veil and no secure flag, regardless of lifecycle.
  disabled,

  /// Veil while backgrounded, secure flag off while foregrounded.
  backgroundOnly,

  /// Secure flag always on; veil while backgrounded.
  alwaysSecure,
}

/// Immutable snapshot of the current screen protection state.
class ScreenProtectionState {
  const ScreenProtectionState({
    required this.isVeilActive,
    required this.isSecureFlagEnabled,
    required this.policy,
    required this.screenshotAttemptsBlocked,
  });

  /// Whether the privacy veil is currently drawn over sensitive content.
  final bool isVeilActive;

  /// Whether the native secure window flag is currently enabled.
  final bool isSecureFlagEnabled;

  /// The policy that produced this state.
  final ScreenProtectionPolicy policy;

  /// Total screenshot attempts recorded since service creation.
  final int screenshotAttemptsBlocked;

  /// Returns a copy of this state with the supplied fields replaced.
  ScreenProtectionState copyWith({
    bool? isVeilActive,
    bool? isSecureFlagEnabled,
    ScreenProtectionPolicy? policy,
    int? screenshotAttemptsBlocked,
  }) {
    return ScreenProtectionState(
      isVeilActive: isVeilActive ?? this.isVeilActive,
      isSecureFlagEnabled: isSecureFlagEnabled ?? this.isSecureFlagEnabled,
      policy: policy ?? this.policy,
      screenshotAttemptsBlocked:
          screenshotAttemptsBlocked ?? this.screenshotAttemptsBlocked,
    );
  }

  @override
  String toString() {
    return 'ScreenProtectionState(isVeilActive: $isVeilActive, '
        'isSecureFlagEnabled: $isSecureFlagEnabled, policy: $policy, '
        'screenshotAttemptsBlocked: $screenshotAttemptsBlocked)';
  }
}

/// Platform abstraction used to toggle native window protection flags.
abstract class WindowProtectionPlatformBridge {
  /// Applies or clears the native FLAG_SECURE equivalent.
  void setSecureFlag(bool enabled);

  /// Shows or hides the App Switcher privacy veil.
  void setPrivacyVeil(bool visible);
}

/// Deterministic controller for screen protection and the privacy veil.
///
/// The service starts in [AppLifecycleState.resumed]. The default policy is
/// [ScreenProtectionPolicy.backgroundOnly]: the veil and secure flag are off
/// while the app is resumed, and the veil activates whenever the app leaves the
/// resumed state. The initial state is reconciled onto the bridge at
/// construction time so native flags always match [currentState].
class ScreenProtectionService {
  ScreenProtectionService({
    required WindowProtectionPlatformBridge bridge,
    ScreenProtectionPolicy initialPolicy = ScreenProtectionPolicy.backgroundOnly,
    this.onScreenshotAttempt,
  })  : _bridge = bridge,
        _policy = initialPolicy,
        _lastLifecycleState = AppLifecycleState.resumed,
        _state = const ScreenProtectionState(
          isVeilActive: false,
          isSecureFlagEnabled: false,
          policy: ScreenProtectionPolicy.backgroundOnly,
          screenshotAttemptsBlocked: 0,
        ) {
    _reconcile();
  }

  final WindowProtectionPlatformBridge _bridge;

  /// Optional audit callback invoked with the new count on each attempt.
  final void Function(int count)? onScreenshotAttempt;

  ScreenProtectionPolicy _policy;
  AppLifecycleState _lastLifecycleState;
  ScreenProtectionState _state;

  /// The most recently computed protection state.
  ScreenProtectionState get currentState => _state;

  /// The active policy.
  ScreenProtectionPolicy get policy => _policy;

  /// The most recently observed lifecycle state.
  AppLifecycleState get lifecycleState => _lastLifecycleState;

  /// Updates the policy and immediately reconciles native flags.
  void setPolicy(ScreenProtectionPolicy policy) {
    _policy = policy;
    _reconcile();
  }

  /// Records a lifecycle change and reconciles native flags.
  void handleLifecycleChange(AppLifecycleState newState) {
    _lastLifecycleState = newState;
    _reconcile();
  }

  /// Records a blocked screenshot attempt and notifies the audit callback.
  void registerScreenshotAttempt() {
    _state = _state.copyWith(
      screenshotAttemptsBlocked: _state.screenshotAttemptsBlocked + 1,
    );
    onScreenshotAttempt?.call(_state.screenshotAttemptsBlocked);
  }

  void _reconcile() {
    final bool backgrounded = _lastLifecycleState != AppLifecycleState.resumed;

    final bool veil;
    final bool secureFlag;
    switch (_policy) {
      case ScreenProtectionPolicy.disabled:
        veil = false;
        secureFlag = false;
        break;
      case ScreenProtectionPolicy.backgroundOnly:
        veil = backgrounded;
        secureFlag = false;
        break;
      case ScreenProtectionPolicy.alwaysSecure:
        veil = backgrounded;
        secureFlag = true;
        break;
    }

    _state = _state.copyWith(
      isVeilActive: veil,
      isSecureFlagEnabled: secureFlag,
      policy: _policy,
    );

    _bridge.setSecureFlag(secureFlag);
    _bridge.setPrivacyVeil(veil);
  }
}
