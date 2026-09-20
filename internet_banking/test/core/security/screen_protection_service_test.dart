import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/screen_protection_service.dart';

class _RecordingWindowProtectionBridge
    implements WindowProtectionPlatformBridge {
  final List<bool> secureFlagCalls = <bool>[];
  final List<bool> privacyVeilCalls = <bool>[];

  bool? get lastSecureFlag =>
      secureFlagCalls.isEmpty ? null : secureFlagCalls.last;

  bool? get lastPrivacyVeil =>
      privacyVeilCalls.isEmpty ? null : privacyVeilCalls.last;

  @override
  void setSecureFlag(bool enabled) {
    secureFlagCalls.add(enabled);
  }

  @override
  void setPrivacyVeil(bool visible) {
    privacyVeilCalls.add(visible);
  }
}

ScreenProtectionService _service({
  required _RecordingWindowProtectionBridge bridge,
  ScreenProtectionPolicy initialPolicy = ScreenProtectionPolicy.backgroundOnly,
  void Function(int count)? onScreenshotAttempt,
}) {
  return ScreenProtectionService(
    bridge: bridge,
    initialPolicy: initialPolicy,
    onScreenshotAttempt: onScreenshotAttempt,
  );
}

void main() {
  group('Default construction', () {
    test('Default policy is backgroundOnly and starts resumed with everything off',
        () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      expect(service.policy, ScreenProtectionPolicy.backgroundOnly);
      expect(service.lifecycleState, AppLifecycleState.resumed);
      expect(service.currentState.policy, ScreenProtectionPolicy.backgroundOnly);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isFalse);
      expect(service.currentState.screenshotAttemptsBlocked, 0);

      expect(bridge.lastSecureFlag, isFalse);
      expect(bridge.lastPrivacyVeil, isFalse);
    });

    test('Initial state is reconciled onto the bridge at construction', () {
      final bridge = _RecordingWindowProtectionBridge();
      _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.alwaysSecure,
      );

      expect(bridge.secureFlagCalls, isNotEmpty);
      expect(bridge.privacyVeilCalls, isNotEmpty);
      expect(bridge.lastSecureFlag, isTrue);
      expect(bridge.lastPrivacyVeil, isFalse);
    });
  });

  group('backgroundOnly lifecycle state machine', () {
    test('Veil activates for inactive, paused, detached, hidden and clears on resumed',
        () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      const expectedBackgrounded = <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ];

      for (final state in expectedBackgrounded) {
        service.handleLifecycleChange(state);
        expect(
          service.currentState.isVeilActive,
          isTrue,
          reason: 'veil should be active for $state',
        );
        expect(
          service.currentState.isSecureFlagEnabled,
          isFalse,
          reason: 'secure flag stays off for backgroundOnly in $state',
        );
      }

      service.handleLifecycleChange(AppLifecycleState.resumed);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isFalse);
    });

    test('Full transition sequence records deterministic bridge values', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      service.handleLifecycleChange(AppLifecycleState.inactive);
      service.handleLifecycleChange(AppLifecycleState.paused);
      service.handleLifecycleChange(AppLifecycleState.hidden);
      service.handleLifecycleChange(AppLifecycleState.detached);
      service.handleLifecycleChange(AppLifecycleState.resumed);

      expect(
        bridge.privacyVeilCalls,
        <bool>[false, true, true, true, true, false],
      );
      expect(
        bridge.secureFlagCalls.every((value) => value == false),
        isTrue,
      );
      expect(service.currentState.isVeilActive, isFalse);
    });
  });

  group('alwaysSecure policy', () {
    test('Secure flag remains enabled across all lifecycle states', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.alwaysSecure,
      );

      for (final state in AppLifecycleState.values) {
        service.handleLifecycleChange(state);
        expect(
          service.currentState.isSecureFlagEnabled,
          isTrue,
          reason: 'secure flag must stay on for $state',
        );
        expect(bridge.lastSecureFlag, isTrue);
      }
    });

    test('Veil is on only when not resumed', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.alwaysSecure,
      );

      service.handleLifecycleChange(AppLifecycleState.resumed);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isTrue);

      service.handleLifecycleChange(AppLifecycleState.inactive);
      expect(service.currentState.isVeilActive, isTrue);

      service.handleLifecycleChange(AppLifecycleState.paused);
      expect(service.currentState.isVeilActive, isTrue);

      service.handleLifecycleChange(AppLifecycleState.resumed);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isTrue);
    });
  });

  group('disabled policy', () {
    test('Keeps veil and secure flag disabled for every lifecycle state', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.disabled,
      );

      for (final state in AppLifecycleState.values) {
        service.handleLifecycleChange(state);
        expect(service.currentState.isVeilActive, isFalse);
        expect(service.currentState.isSecureFlagEnabled, isFalse);
      }

      expect(
        bridge.privacyVeilCalls.every((value) => value == false),
        isTrue,
      );
      expect(
        bridge.secureFlagCalls.every((value) => value == false),
        isTrue,
      );
    });
  });

  group('Policy changes', () {
    test('Switching from backgroundOnly to alwaysSecure enables secure flag immediately',
        () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      expect(service.currentState.isSecureFlagEnabled, isFalse);

      service.setPolicy(ScreenProtectionPolicy.alwaysSecure);

      expect(service.currentState.policy, ScreenProtectionPolicy.alwaysSecure);
      expect(service.currentState.isSecureFlagEnabled, isTrue);
      expect(bridge.lastSecureFlag, isTrue);
    });

    test('Switching to disabled while backgrounded clears veil and secure flag', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.alwaysSecure,
      );

      service.handleLifecycleChange(AppLifecycleState.paused);
      expect(service.currentState.isVeilActive, isTrue);

      service.setPolicy(ScreenProtectionPolicy.disabled);

      expect(service.currentState.policy, ScreenProtectionPolicy.disabled);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isFalse);
      expect(bridge.lastPrivacyVeil, isFalse);
      expect(bridge.lastSecureFlag, isFalse);
    });

    test('Switching to backgroundOnly while resumed clears everything', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(
        bridge: bridge,
        initialPolicy: ScreenProtectionPolicy.alwaysSecure,
      );

      expect(service.currentState.isSecureFlagEnabled, isTrue);

      service.setPolicy(ScreenProtectionPolicy.backgroundOnly);

      expect(service.currentState.policy, ScreenProtectionPolicy.backgroundOnly);
      expect(service.currentState.isVeilActive, isFalse);
      expect(service.currentState.isSecureFlagEnabled, isFalse);
    });

    test('setPolicy reconciles against the retained lifecycle state', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      service.handleLifecycleChange(AppLifecycleState.hidden);
      service.setPolicy(ScreenProtectionPolicy.alwaysSecure);

      expect(service.lifecycleState, AppLifecycleState.hidden);
      expect(service.currentState.isVeilActive, isTrue);
      expect(service.currentState.isSecureFlagEnabled, isTrue);
    });
  });

  group('Screenshot attempt auditing', () {
    test('Counter increments and callback fires with the new count', () {
      final bridge = _RecordingWindowProtectionBridge();
      final counts = <int>[];
      final service = _service(
        bridge: bridge,
        onScreenshotAttempt: counts.add,
      );

      service.registerScreenshotAttempt();
      expect(service.currentState.screenshotAttemptsBlocked, 1);

      service.registerScreenshotAttempt();
      expect(service.currentState.screenshotAttemptsBlocked, 2);

      service.registerScreenshotAttempt();
      expect(service.currentState.screenshotAttemptsBlocked, 3);

      expect(counts, <int>[1, 2, 3]);
    });

    test('Screenshot attempts do not alter veil or secure flag state', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      final secureCallsBefore = bridge.secureFlagCalls.length;
      final veilCallsBefore = bridge.privacyVeilCalls.length;

      service.registerScreenshotAttempt();

      expect(bridge.secureFlagCalls.length, secureCallsBefore);
      expect(bridge.privacyVeilCalls.length, veilCallsBefore);
    });

    test('Registration works without an audit callback', () {
      final bridge = _RecordingWindowProtectionBridge();
      final service = _service(bridge: bridge);

      service.registerScreenshotAttempt();
      service.registerScreenshotAttempt();

      expect(service.currentState.screenshotAttemptsBlocked, 2);
    });
  });

  group('ScreenProtectionState copyWith', () {
    test('copyWith replaces only the supplied fields', () {
      const original = ScreenProtectionState(
        isVeilActive: false,
        isSecureFlagEnabled: true,
        policy: ScreenProtectionPolicy.alwaysSecure,
        screenshotAttemptsBlocked: 4,
      );

      final updated = original.copyWith(
        isVeilActive: true,
        screenshotAttemptsBlocked: 5,
      );

      expect(updated.isVeilActive, isTrue);
      expect(updated.isSecureFlagEnabled, isTrue);
      expect(updated.policy, ScreenProtectionPolicy.alwaysSecure);
      expect(updated.screenshotAttemptsBlocked, 5);
    });
  });
}
