import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/biometric_auth_service.dart';

const BiometricCapability _readyCapability = BiometricCapability(
  hardwareType: BiometricHardwareType.fingerprint,
  isAvailable: true,
  isEnrolled: true,
  supportedTypes: <BiometricHardwareType>[BiometricHardwareType.fingerprint],
);

class _FakeGateway implements BiometricHardwareGateway {
  _FakeGateway({
    BiometricCapability capability = _readyCapability,
    this.authResult = true,
    this.throwOnAuthenticate = false,
    this.throwOnSign = false,
    this.signatureBuilder,
  }) : _capability = capability;

  BiometricCapability _capability;
  bool authResult;
  bool throwOnAuthenticate;
  bool throwOnSign;
  BiometricSignatureResult Function(String nonce, DateTime timestamp)?
      signatureBuilder;

  int capabilityCalls = 0;
  int authenticateCalls = 0;
  int signCalls = 0;

  void setCapability(BiometricCapability capability) => _capability = capability;

  @override
  Future<BiometricCapability> getCapability() async {
    capabilityCalls++;
    return _capability;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    if (throwOnAuthenticate) {
      throw StateError('hardware failure');
    }
    return authResult;
  }

  @override
  Future<BiometricSignatureResult> signChallenge({
    required String challengeNonce,
    required DateTime timestamp,
  }) async {
    signCalls++;
    if (throwOnSign) {
      throw StateError('signing failure');
    }
    final builder = signatureBuilder;
    if (builder != null) {
      return builder(challengeNonce, timestamp);
    }
    return BiometricSignatureResult(
      signature: 'sig:$challengeNonce',
      timestamp: timestamp,
      nonce: challengeNonce,
      authenticatedToken: '',
    );
  }
}

void main() {
  final DateTime epoch = DateTime.utc(2026, 1, 1, 12, 0, 0);
  late DateTime current;
  DateTime clock() => current;

  setUp(() {
    current = epoch;
  });

  group('BiometricCapability model', () {
    for (final type in <BiometricHardwareType>[
      BiometricHardwareType.fingerprint,
      BiometricHardwareType.face,
      BiometricHardwareType.iris,
      BiometricHardwareType.multiple,
    ]) {
      test('isReady is true for $type when available and enrolled', () async {
        final gateway = _FakeGateway(
          capability: BiometricCapability(
            hardwareType: type,
            isAvailable: true,
            isEnrolled: true,
            supportedTypes: <BiometricHardwareType>[type],
          ),
        );
        final service = BiometricAuthService(gateway: gateway, clock: clock);

        final capability = await service.evaluateCapability();
        expect(capability.hardwareType, type);
        expect(capability.isReady, isTrue);
      });
    }

    test('isReady is false when hardware type is none', () {
      const capability = BiometricCapability(
        hardwareType: BiometricHardwareType.none,
        isAvailable: true,
        isEnrolled: true,
      );
      expect(capability.isReady, isFalse);
    });

    test('isReady is false when hardware is not available', () {
      const capability = BiometricCapability(
        hardwareType: BiometricHardwareType.face,
        isAvailable: false,
        isEnrolled: true,
      );
      expect(capability.isReady, isFalse);
    });

    test('isReady is false when no credential is enrolled', () {
      const capability = BiometricCapability(
        hardwareType: BiometricHardwareType.face,
        isAvailable: true,
        isEnrolled: false,
      );
      expect(capability.isReady, isFalse);
    });

    test('supportedTypes are preserved by the capability', () {
      const capability = BiometricCapability(
        hardwareType: BiometricHardwareType.multiple,
        isAvailable: true,
        isEnrolled: true,
        supportedTypes: <BiometricHardwareType>[
          BiometricHardwareType.fingerprint,
          BiometricHardwareType.face,
        ],
      );
      expect(capability.supportedTypes, <BiometricHardwareType>[
        BiometricHardwareType.fingerprint,
        BiometricHardwareType.face,
      ]);
    });

    test('copyWith replaces only the provided fields', () {
      const capability = _readyCapability;
      final updated = capability.copyWith(isEnrolled: false);
      expect(updated.isEnrolled, isFalse);
      expect(updated.isAvailable, isTrue);
      expect(updated.hardwareType, BiometricHardwareType.fingerprint);
    });
  });

  group('evaluateCapability caching', () {
    test('queries the gateway only once and caches the result', () async {
      final gateway = _FakeGateway();
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      final first = await service.evaluateCapability();
      final second = await service.evaluateCapability();

      expect(first, same(second));
      expect(gateway.capabilityCalls, 1);
    });
  });

  group('authenticate status mapping', () {
    test('true maps to success and resets failures', () async {
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 5,
      );

      expect(await service.authenticate(), BiometricAuthStatus.canceled);
      expect(await service.authenticate(), BiometricAuthStatus.canceled);
      expect(service.failedAttempts, 2);

      gateway.authResult = true;
      expect(await service.authenticate(), BiometricAuthStatus.success);
      expect(service.failedAttempts, 0);
      expect(service.isLockedOut, isFalse);
    });

    test('false maps to canceled and records a failure', () async {
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      final status = await service.authenticate(reason: 'Confirm payment');

      expect(status, BiometricAuthStatus.canceled);
      expect(service.failedAttempts, 1);
      expect(gateway.authenticateCalls, 1);
    });

    test('a thrown hardware error maps to failed', () async {
      final gateway = _FakeGateway(throwOnAuthenticate: true);
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      final status = await service.authenticate();

      expect(status, BiometricAuthStatus.failed);
      expect(service.failedAttempts, 1);
    });

    test('not ready capability maps to notAvailable without hardware call',
        () async {
      final gateway = _FakeGateway(
        capability: const BiometricCapability(
          hardwareType: BiometricHardwareType.none,
          isAvailable: false,
          isEnrolled: false,
        ),
      );
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      final status = await service.authenticate();

      expect(status, BiometricAuthStatus.notAvailable);
      expect(gateway.authenticateCalls, 0);
      expect(service.failedAttempts, 0);
    });

    test('not enrolled capability maps to notAvailable without hardware call',
        () async {
      final gateway = _FakeGateway(
        capability: const BiometricCapability(
          hardwareType: BiometricHardwareType.face,
          isAvailable: true,
          isEnrolled: false,
        ),
      );
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      expect(await service.authenticate(), BiometricAuthStatus.notAvailable);
      expect(gateway.authenticateCalls, 0);
    });
  });

  group('authenticateWithChallenge', () {
    test('valid challenge returns result with generated session token',
        () async {
      final gateway = _FakeGateway();
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      final result = await service.authenticateWithChallenge(
        challengeNonce: 'nonce-1',
      );

      expect(result.nonce, 'nonce-1');
      expect(result.timestamp, epoch);
      expect(result.signature, 'sig:nonce-1');
      expect(
        result.authenticatedToken,
        service.generateSessionToken(nonce: 'nonce-1', issuedAt: epoch),
      );
      expect(service.failedAttempts, 0);
    });

    test('session token is deterministic for a fixed clock and nonce', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
      );
      final issuedAt = DateTime.utc(2026, 1, 1, 11, 59, 30);

      final first = service.generateSessionToken(nonce: 'abc', issuedAt: issuedAt);
      final second =
          service.generateSessionToken(nonce: 'abc', issuedAt: issuedAt);

      expect(first, second);
      expect(first, isNot(isEmpty));
    });

    test('session token changes with the nonce', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
      );
      final issuedAt = DateTime.utc(2026, 1, 1, 11, 59, 30);

      expect(
        service.generateSessionToken(nonce: 'abc', issuedAt: issuedAt),
        isNot(service.generateSessionToken(nonce: 'xyz', issuedAt: issuedAt)),
      );
    });

    test('session token changes with the timestamp', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
      );
      final issuedAt = DateTime.utc(2026, 1, 1, 11, 59, 30);

      expect(
        service.generateSessionToken(nonce: 'abc', issuedAt: issuedAt),
        isNot(service.generateSessionToken(
          nonce: 'abc',
          issuedAt: issuedAt.add(const Duration(seconds: 1)),
        )),
      );
    });

    test('stale challenge timestamp is rejected and records a failure',
        () async {
      final gateway = _FakeGateway(
        signatureBuilder: (nonce, timestamp) => BiometricSignatureResult(
          signature: 'sig',
          timestamp: timestamp.subtract(const Duration(minutes: 2)),
          nonce: nonce,
          authenticatedToken: '',
        ),
      );
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxChallengeAge: const Duration(minutes: 1),
      );

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
      expect(service.failedAttempts, 1);
    });

    test('future challenge timestamp is rejected', () async {
      final gateway = _FakeGateway(
        signatureBuilder: (nonce, timestamp) => BiometricSignatureResult(
          signature: 'sig',
          timestamp: timestamp.add(const Duration(seconds: 5)),
          nonce: nonce,
          authenticatedToken: '',
        ),
      );
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('nonce mismatch is rejected', () async {
      final gateway = _FakeGateway(
        signatureBuilder: (nonce, timestamp) => BiometricSignatureResult(
          signature: 'sig',
          timestamp: timestamp,
          nonce: 'tampered-nonce',
          authenticatedToken: '',
        ),
      );
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
      expect(service.failedAttempts, 1);
    });

    test('signing failure is surfaced as StateError', () async {
      final gateway = _FakeGateway(throwOnSign: true);
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('not ready capability throws StateError without signing', () async {
      final gateway = _FakeGateway(
        capability: const BiometricCapability(
          hardwareType: BiometricHardwareType.none,
          isAvailable: false,
          isEnrolled: false,
        ),
      );
      final service = BiometricAuthService(gateway: gateway, clock: clock);

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
      expect(gateway.signCalls, 0);
    });

    test('locked out throws StateError without signing', () async {
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 1,
      );

      expect(await service.authenticate(), BiometricAuthStatus.lockedOut);
      expect(service.isLockedOut, isTrue);

      await expectLater(
        service.authenticateWithChallenge(challengeNonce: 'nonce-1'),
        throwsA(isA<StateError>()),
      );
      expect(gateway.signCalls, 0);
    });
  });

  group('isChallengeFresh', () {
    test('fresh timestamp is accepted', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
        maxChallengeAge: const Duration(minutes: 1),
      );

      expect(service.isChallengeFresh(epoch), isTrue);
      expect(
        service.isChallengeFresh(epoch.subtract(const Duration(seconds: 60))),
        isTrue,
      );
    });

    test('too old timestamp is rejected', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
        maxChallengeAge: const Duration(minutes: 1),
      );

      expect(
        service.isChallengeFresh(
          epoch.subtract(const Duration(seconds: 61)),
        ),
        isFalse,
      );
    });

    test('future timestamp is rejected', () {
      final service = BiometricAuthService(
        gateway: _FakeGateway(),
        clock: clock,
      );

      expect(service.isChallengeFresh(epoch.add(const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('Lockout and exponential backoff', () {
    test('locks after maxFailedAttempts and blocks hardware calls', () async {
      final start = epoch;
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 3,
        baseLockoutDuration: const Duration(seconds: 30),
      );

      expect(await service.authenticate(), BiometricAuthStatus.canceled);
      expect(await service.authenticate(), BiometricAuthStatus.canceled);
      expect(service.isLockedOut, isFalse);

      expect(await service.authenticate(), BiometricAuthStatus.lockedOut);
      expect(service.failedAttempts, 3);
      expect(service.lockoutCount, 1);
      expect(service.isLockedOut, isTrue);
      expect(service.lockoutUntil, start.add(const Duration(seconds: 30)));
      expect(service.remainingLockout, const Duration(seconds: 30));

      final calls = gateway.authenticateCalls;
      current = start.add(const Duration(seconds: 10));
      expect(await service.authenticate(), BiometricAuthStatus.lockedOut);
      expect(gateway.authenticateCalls, calls);
      expect(service.remainingLockout, const Duration(seconds: 20));

      current = start.add(const Duration(seconds: 30)).subtract(
            const Duration(microseconds: 1),
          );
      expect(service.isLockedOut, isTrue);
      expect(service.remainingLockout, const Duration(microseconds: 1));

      current = start.add(const Duration(seconds: 30));
      expect(service.isLockedOut, isFalse);
      expect(service.remainingLockout, Duration.zero);
    });

    test('lockout duration doubles per episode', () async {
      final start = epoch;
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 3,
        baseLockoutDuration: const Duration(seconds: 30),
      );

      for (var i = 0; i < 3; i++) {
        await service.authenticate();
      }
      expect(service.lockoutCount, 1);
      expect(service.remainingLockout, const Duration(seconds: 30));

      current = start.add(const Duration(seconds: 30));
      expect(service.isLockedOut, isFalse);
      await service.authenticate();
      expect(service.lockoutCount, 2);
      expect(service.remainingLockout, const Duration(seconds: 60));

      current = start.add(const Duration(seconds: 90));
      expect(service.isLockedOut, isFalse);
      await service.authenticate();
      expect(service.lockoutCount, 3);
      expect(service.remainingLockout, const Duration(seconds: 120));
    });

    test('lockout duration is capped at maxLockoutDuration', () async {
      final start = epoch;
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 3,
        baseLockoutDuration: const Duration(seconds: 30),
        maxLockoutDuration: const Duration(minutes: 2),
      );

      for (var i = 0; i < 3; i++) {
        await service.authenticate();
      }
      expect(service.remainingLockout, const Duration(seconds: 30));

      current = start.add(const Duration(seconds: 30));
      await service.authenticate();
      expect(service.remainingLockout, const Duration(seconds: 60));

      current = start.add(const Duration(seconds: 90));
      await service.authenticate();
      expect(service.remainingLockout, const Duration(seconds: 120));

      current = start.add(const Duration(seconds: 210));
      await service.authenticate();
      expect(service.lockoutCount, 4);
      expect(service.remainingLockout, const Duration(seconds: 120));
    });

    test('recovers after lockout expires on successful authentication',
        () async {
      final start = epoch;
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 3,
        baseLockoutDuration: const Duration(seconds: 30),
      );

      for (var i = 0; i < 3; i++) {
        await service.authenticate();
      }
      expect(service.isLockedOut, isTrue);

      current = start.add(const Duration(seconds: 31));
      expect(service.isLockedOut, isFalse);
      expect(service.remainingLockout, Duration.zero);

      gateway.authResult = true;
      expect(await service.authenticate(), BiometricAuthStatus.success);
      expect(service.failedAttempts, 0);
      expect(service.lockoutCount, 0);
      expect(service.lockoutUntil, isNull);
      expect(service.remainingLockout, Duration.zero);
    });

    test('lockout expiry timing is exact relative to the injected clock',
        () async {
      final start = epoch;
      final gateway = _FakeGateway(authResult: false);
      final service = BiometricAuthService(
        gateway: gateway,
        clock: clock,
        maxFailedAttempts: 1,
        baseLockoutDuration: const Duration(seconds: 45),
      );

      expect(await service.authenticate(), BiometricAuthStatus.lockedOut);
      expect(service.lockoutUntil, start.add(const Duration(seconds: 45)));

      current = start.add(const Duration(seconds: 44));
      expect(service.isLockedOut, isTrue);

      current = start.add(const Duration(seconds: 45));
      expect(service.isLockedOut, isFalse);
    });
  });
}
