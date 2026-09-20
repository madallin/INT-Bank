import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/inactivity_lock_service.dart';

void main() {
  DateTime current = DateTime.utc(2026, 1, 1);
  DateTime clock() => current;
  void advance(Duration duration) {
    current = current.add(duration);
  }

  setUp(() {
    current = DateTime.utc(2026, 1, 1);
  });

  group('InactivityLockService defaults', () {
    test('exposes default constants', () {
      expect(InactivityLockService.defaultTimeoutSeconds, 300);
      expect(InactivityLockService.defaultWarningWindowSeconds, 30);
    });

    test('applies default configuration', () {
      final service = InactivityLockService(clock: clock);
      expect(service.timeout, const Duration(seconds: 300));
      expect(service.warningWindow, const Duration(seconds: 30));
      expect(service.lockGracePeriod, const Duration(seconds: 60));
    });

    test('start() enters active with a full countdown', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      expect(service.state, InactivityLockState.active);
      expect(service.isActive, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.isTerminated, isFalse);
      expect(service.lastActivityAt, current);
      expect(service.remaining, const Duration(seconds: 300));
      expect(service.shouldShowPrivacyVeil, isFalse);
      expect(service.requiresReauthentication, isFalse);
    });
  });

  group('active -> warningCountdown', () {
    test('enters warning exactly at the last 30 seconds and warns once', () {
      final service = InactivityLockService(clock: clock);
      Duration? warnedRemaining;
      int warnings = 0;
      service.start(onWarning: (Duration remaining) {
        warnedRemaining = remaining;
        warnings++;
      });

      advance(const Duration(seconds: 269));
      service.tick();
      expect(service.state, InactivityLockState.active);

      advance(const Duration(seconds: 1));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);
      expect(warnings, 1);
      expect(warnedRemaining, const Duration(seconds: 30));
      expect(service.warningRemaining, const Duration(seconds: 30));

      service.tick();
      service.tick();
      expect(warnings, 1);

      advance(const Duration(seconds: 10));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);
      expect(warnings, 1);
      expect(service.warningRemaining, const Duration(seconds: 20));
    });
  });

  group('warningCountdown -> locked', () {
    test('locks at zero and fires lock and privacy veil once', () {
      final service = InactivityLockService(clock: clock);
      int locks = 0;
      int veils = 0;
      int reauths = 0;
      service.start(
        onLock: () => locks++,
        onPrivacyVeilRequired: () => veils++,
        onReauthenticationRequired: () => reauths++,
      );

      advance(const Duration(seconds: 300));
      service.tick();

      expect(service.state, InactivityLockState.locked);
      expect(service.isLocked, isTrue);
      expect(service.remaining, Duration.zero);
      expect(service.shouldShowPrivacyVeil, isTrue);
      expect(service.requiresReauthentication, isTrue);
      expect(locks, 1);
      expect(veils, 1);
      expect(reauths, 1);

      service.tick();
      service.tick();
      expect(locks, 1);
      expect(veils, 1);
      expect(reauths, 1);
    });

    test('active -> warningCountdown -> locked transition chain', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 275));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);

      advance(const Duration(seconds: 25));
      service.tick();
      expect(service.state, InactivityLockState.locked);
    });
  });

  group('locked -> terminated', () {
    test('terminates after the lock grace period and fires once', () {
      final service = InactivityLockService(clock: clock);
      int terminations = 0;
      service.start(onTerminate: () => terminations++);

      advance(const Duration(seconds: 300));
      service.tick();
      expect(service.state, InactivityLockState.locked);

      advance(const Duration(seconds: 59));
      service.tick();
      expect(service.state, InactivityLockState.locked);
      expect(terminations, 0);

      advance(const Duration(seconds: 1));
      service.tick();
      expect(service.state, InactivityLockState.terminated);
      expect(service.isTerminated, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.shouldShowPrivacyVeil, isTrue);
      expect(terminations, 1);

      service.tick();
      expect(terminations, 1);
    });

    test('terminate() transitions explicitly and fires once', () {
      final service = InactivityLockService(clock: clock);
      int terminations = 0;
      service.start(onTerminate: () => terminations++);

      service.terminate();
      expect(service.state, InactivityLockState.terminated);
      expect(terminations, 1);

      service.terminate();
      expect(terminations, 1);
    });
  });

  group('activity resets and cancels warning', () {
    test('recordTouch resets countdown and cancels a warning', () {
      final service = InactivityLockService(clock: clock);
      int warnings = 0;
      service.start(onWarning: (Duration _) => warnings++);

      advance(const Duration(seconds: 280));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);

      service.recordTouch();
      expect(service.state, InactivityLockState.active);
      expect(service.lastActivityAt, current);
      expect(service.remaining, const Duration(seconds: 300));

      advance(const Duration(seconds: 299));
      service.tick();
      expect(service.isLocked, isFalse);
      expect(service.state, InactivityLockState.warningCountdown);
      expect(warnings, 2);
    });

    test('recordNavigation resets countdown and prevents lock', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 280));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);

      service.recordNavigation();
      expect(service.state, InactivityLockState.active);

      advance(const Duration(seconds: 299));
      service.tick();
      expect(service.isLocked, isFalse);
    });

    test('recordActivity before expiry resets the timer', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 250));
      service.recordActivity();
      expect(service.lastActivityAt, current);
      expect(service.remaining, const Duration(seconds: 300));

      advance(const Duration(seconds: 299));
      service.tick();
      expect(service.isLocked, isFalse);

      advance(const Duration(seconds: 1));
      service.tick();
      expect(service.state, InactivityLockState.locked);
    });

    test('activity is ignored once locked', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 300));
      service.tick();
      expect(service.state, InactivityLockState.locked);

      service.recordTouch();
      service.recordNavigation();
      service.recordActivity();
      expect(service.state, InactivityLockState.locked);
    });
  });

  group('re-authentication unlock', () {
    test('failed authentication keeps the session locked', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 300));
      service.tick();
      expect(service.state, InactivityLockState.locked);

      final bool result = service.unlockWithReauthentication(false);
      expect(result, isFalse);
      expect(service.state, InactivityLockState.locked);
      expect(service.requiresReauthentication, isTrue);
    });

    test('successful authentication restores active with full countdown', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 300));
      service.tick();
      expect(service.state, InactivityLockState.locked);

      advance(const Duration(seconds: 5));
      final bool result = service.unlockWithReauthentication(true);
      expect(result, isTrue);
      expect(service.state, InactivityLockState.active);
      expect(service.isActive, isTrue);
      expect(service.lastActivityAt, current);
      expect(service.remaining, const Duration(seconds: 300));
      expect(service.shouldShowPrivacyVeil, isFalse);

      advance(const Duration(seconds: 270));
      service.tick();
      expect(service.state, InactivityLockState.warningCountdown);
    });

    test('failed authentication after grace period terminates', () {
      final service = InactivityLockService(clock: clock);
      service.start();

      advance(const Duration(seconds: 300));
      service.tick();
      expect(service.state, InactivityLockState.locked);

      advance(const Duration(seconds: 61));
      final bool result = service.unlockWithReauthentication(false);
      expect(result, isFalse);
      expect(service.state, InactivityLockState.terminated);
    });
  });

  group('transition callbacks fire exactly once', () {
    test('repeated ticks do not duplicate notifications', () {
      final service = InactivityLockService(clock: clock);
      int warnings = 0;
      int locks = 0;
      int terminations = 0;
      service.start(
        onWarning: (Duration _) => warnings++,
        onLock: () => locks++,
        onTerminate: () => terminations++,
      );

      advance(const Duration(seconds: 270));
      service.tick();
      service.tick();
      service.tick();
      expect(warnings, 1);
      expect(locks, 0);

      advance(const Duration(seconds: 30));
      service.tick();
      service.tick();
      service.tick();
      expect(locks, 1);
      expect(terminations, 0);

      advance(const Duration(seconds: 60));
      service.tick();
      service.tick();
      service.tick();
      expect(terminations, 1);
    });
  });
}
