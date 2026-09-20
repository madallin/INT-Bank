import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/session_timeout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionTimeoutService Configuration & Defaults', () {
    test('Default timeout is 3 minutes (180 seconds)', () {
      expect(SessionTimeoutService.defaultTimeout, const Duration(minutes: 3));
      expect(SessionTimeoutService.defaultTimeoutSeconds, 180);

      final service = SessionTimeoutService.test();
      expect(service.timeout, const Duration(minutes: 3));
    });

    test('Custom timeout can be configured', () {
      final service = SessionTimeoutService.test(
        timeout: const Duration(seconds: 45),
      );
      expect(service.timeout, const Duration(seconds: 45));
    });

    test('Singleton instance is consistent', () {
      final s1 = SessionTimeoutService.instance;
      final s2 = SessionTimeoutService();
      expect(identical(s1, s2), isTrue);
    });
  });

  group('Session Inactivity Timer & Interaction Reset', () {
    test('start() activates timer and sets running state', () {
      final service = SessionTimeoutService.test();
      service.start();
      expect(service.isRunning, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.remainingTime.inSeconds, greaterThan(0));
      service.dispose();
    });

    test('recordUserActivity / resetTimer / recordInteraction updates last activity', () async {
      final service = SessionTimeoutService.test(timeout: const Duration(seconds: 10));
      service.start();
      final initialTime = service.lastActivityTime;

      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.recordUserActivity();
      expect(service.lastActivityTime.isAfter(initialTime), isTrue);

      final secondTime = service.lastActivityTime;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.resetTimer();
      expect(service.lastActivityTime.isAfter(secondTime), isTrue);

      final thirdTime = service.lastActivityTime;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.recordInteraction();
      expect(service.lastActivityTime.isAfter(thirdTime), isTrue);

      service.dispose();
    });

    test('Inactivity triggers onTimeout callback after duration', () async {
      bool timedOut = false;
      final service = SessionTimeoutService.test(
        timeout: const Duration(milliseconds: 100),
      );

      service.start(onTimeout: () {
        timedOut = true;
      });

      expect(timedOut, isFalse);
      expect(service.isLocked, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(timedOut, isTrue);
      expect(service.isLocked, isTrue);
      expect(service.isRunning, isFalse);
      expect(service.remainingTime, Duration.zero);

      service.dispose();
    });

    test('User interaction resets timeout timer and prevents premature timeout', () async {
      bool timedOut = false;
      final service = SessionTimeoutService.test(
        timeout: const Duration(milliseconds: 120),
      );

      service.start(onTimeout: () {
        timedOut = true;
      });

      // At 60ms, user interacts
      await Future<void>.delayed(const Duration(milliseconds: 60));
      service.recordUserActivity();

      // At 100ms from start (40ms after interaction), should NOT be timed out
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(timedOut, isFalse);
      expect(service.isLocked, isFalse);

      // Wait remaining 100ms (140ms after interaction) -> should time out
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timedOut, isTrue);
      expect(service.isLocked, isTrue);

      service.dispose();
    });
  });

  group('App Lifecycle State & Background Timeout Detection', () {
    test('App transition to paused/inactive sets background state', () {
      final service = SessionTimeoutService.test();
      service.start();

      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(service.isBackgrounded, isTrue);
      expect(service.backgroundTime, isNotNull);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.isBackgrounded, isTrue);

      service.dispose();
    });

    test('Resuming app after >= 180s (timeout duration) in background locks session immediately', () async {
      bool loggedOut = false;
      final service = SessionTimeoutService.test(
        timeout: const Duration(milliseconds: 80),
      );

      service.start(onTimeout: () {
        loggedOut = true;
      });

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.isBackgrounded, isTrue);

      // Sleep past the timeout while in background
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // Resume app
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(service.isBackgrounded, isFalse);
      expect(loggedOut, isTrue);
      expect(service.isLocked, isTrue);

      service.dispose();
    });

    test('Resuming app within timeout duration resumes countdown without locking', () async {
      bool loggedOut = false;
      final service = SessionTimeoutService.test(
        timeout: const Duration(milliseconds: 200),
      );

      service.start(onTimeout: () {
        loggedOut = true;
      });

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.isBackgrounded, isTrue);

      // In background for 50ms (< 200ms)
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Resume app
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(service.isBackgrounded, isFalse);
      expect(loggedOut, isFalse);
      expect(service.isLocked, isFalse);
      expect(service.isRunning, isTrue);

      // Remaining duration expires
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(loggedOut, isTrue);
      expect(service.isLocked, isTrue);

      service.dispose();
    });
  });

  group('Lock, Unlock, Stop & Dispose', () {
    test('lockSession() manually locks and executes callback', () {
      bool called = false;
      final service = SessionTimeoutService.test(
        onTimeout: () => called = true,
      );
      service.start();

      service.lockSession();
      expect(called, isTrue);
      expect(service.isLocked, isTrue);
      expect(service.isRunning, isFalse);

      service.dispose();
    });

    test('unlockSession() clears lock and restarts timer', () {
      final service = SessionTimeoutService.test();
      service.start();
      service.lockSession();
      expect(service.isLocked, isTrue);

      service.unlockSession();
      expect(service.isLocked, isFalse);
      expect(service.isRunning, isTrue);

      service.dispose();
    });

    test('stop() cancels running timer', () async {
      bool timedOut = false;
      final service = SessionTimeoutService.test(
        timeout: const Duration(milliseconds: 50),
        onTimeout: () => timedOut = true,
      );
      service.start();
      service.stop();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timedOut, isFalse);
      expect(service.isRunning, isFalse);

      service.dispose();
    });
  });
}
