import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/account_security_validator.dart';

void main() {
  const List<int> secretKey = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  final DateTime base = DateTime.utc(2026, 1, 1, 12, 0, 0);

  late DateTime current;
  DateTime clock() => current;

  var nonceCounter = 0;
  String nonceGenerator() {
    nonceCounter += 1;
    return 'nonce-${nonceCounter.toString().padLeft(8, '0')}';
  }

  late AccountSecurityValidator validator;

  AccountOwnershipClaim ownedClaim() => const AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-1',
        owningUserId: 'user-42',
      );

  HmacSecurityEnvelope signEnvelope({
    required AccountOwnershipClaim claim,
    required String nonce,
    required DateTime timestamp,
    String? keyId,
  }) {
    final payload = validator.buildCanonicalPayload(
      authenticatedUserId: claim.authenticatedUserId,
      requestedAccountId: claim.requestedAccountId,
      nonce: nonce,
      timestamp: timestamp,
      keyId: keyId,
    );
    return HmacSecurityEnvelope(
      nonce: nonce,
      timestamp: timestamp,
      signature: validator.computeSignature(payload),
      keyId: keyId,
    );
  }

  setUp(() {
    current = base;
    nonceCounter = 0;
    validator = AccountSecurityValidator(
      secretKey: secretKey,
      clock: clock,
      nonceGenerator: nonceGenerator,
    );
  });

  group('AccountOwnershipClaim', () {
    test('owned when resolved owner matches the authenticated user', () {
      expect(ownedClaim().isOwnedByAuthenticatedUser, isTrue);
      expect(ownedClaim().isOwnershipMismatch, isFalse);
    });

    test('not owned when resolved owner differs (BOLA/IDOR)', () {
      const claim = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-99',
        owningUserId: 'user-7',
      );
      expect(claim.isOwnedByAuthenticatedUser, isFalse);
      expect(claim.isOwnershipMismatch, isTrue);
    });

    test('unknown owner fails closed', () {
      const claim = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-1',
      );
      expect(claim.isOwnedByAuthenticatedUser, isFalse);
      expect(claim.isOwnershipMismatch, isTrue);
    });

    test('copyWith replaces only provided fields', () {
      final copy = ownedClaim().copyWith(requestedAccountId: 'acc-2');
      expect(copy.authenticatedUserId, 'user-42');
      expect(copy.requestedAccountId, 'acc-2');
      expect(copy.owningUserId, 'user-42');
    });
  });

  group('validateOwnership', () {
    test('matching ownership succeeds', () {
      expect(validator.validateOwnership(ownedClaim()), ValidationOutcome.success);
    });

    test('mismatched ownership is rejected', () {
      const claim = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-99',
        owningUserId: 'user-7',
      );
      expect(
        validator.validateOwnership(claim),
        ValidationOutcome.ownershipMismatch,
      );
    });
  });

  group('signed envelope happy path', () {
    test('fresh timestamp and unused nonce validate successfully', () {
      final envelope = validator.createEnvelope(ownedClaim());
      expect(envelope.nonce, 'nonce-00000001');
      expect(envelope.timestamp, base);
      expect(envelope.timestamp.isUtc, isTrue);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(envelope.signature), isTrue);

      final outcome = validator.validateEnvelope(ownedClaim(), envelope);
      expect(outcome, ValidationOutcome.success);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.isValid, isTrue);
      expect(validator.usedNonceCount, 1);
      expect(validator.isNonceUsed(envelope.nonce), isTrue);
    });

    test('keyId is bound into the envelope and signature', () {
      final envelope = validator.createEnvelope(ownedClaim(), keyId: 'key-1');
      expect(envelope.keyId, 'key-1');
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
    });

    test('success increments used nonce count per envelope', () {
      final first = validator.createEnvelope(ownedClaim());
      final second = validator.createEnvelope(ownedClaim());
      expect(first.nonce, isNot(second.nonce));
      expect(
        validator.validateEnvelope(ownedClaim(), first),
        ValidationOutcome.success,
      );
      expect(
        validator.validateEnvelope(ownedClaim(), second),
        ValidationOutcome.success,
      );
      expect(validator.usedNonceCount, 2);
    });

    test('fromSecretString matches raw utf8 key bytes', () {
      final stringValidator = AccountSecurityValidator.fromSecretString(
        secret: 'top-secret',
        clock: clock,
        nonceGenerator: nonceGenerator,
      );
      final bytesValidator = AccountSecurityValidator(
        secretKey: utf8.encode('top-secret'),
        clock: clock,
        nonceGenerator: nonceGenerator,
      );
      const payload = 'accountId=acc-1&userId=user-42';
      expect(
        stringValidator.computeSignature(payload),
        bytesValidator.computeSignature(payload),
      );
    });

    test('empty secret is rejected', () {
      expect(
        () => AccountSecurityValidator(
          secretKey: const <int>[],
          clock: clock,
          nonceGenerator: nonceGenerator,
        ),
        throwsArgumentError,
      );
    });
  });

  group('BOLA/IDOR ownership defense', () {
    test('valid signature on a foreign account is rejected and not accepted', () {
      const foreign = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-99',
        owningUserId: 'user-7',
      );
      final envelope = validator.createEnvelope(foreign);

      final outcome = validator.validateEnvelope(foreign, envelope);
      expect(outcome, ValidationOutcome.ownershipMismatch);
      expect(outcome.isValid, isFalse);
      expect(validator.isNonceUsed(envelope.nonce), isFalse);
      expect(validator.usedNonceCount, 0);
    });

    test('mismatch is reported before signature integrity', () {
      const foreign = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-99',
        owningUserId: 'user-7',
      );
      final tampered = HmacSecurityEnvelope(
        nonce: 'nonce-00000001',
        timestamp: base,
        signature: 'deadbeef',
      );
      expect(
        validator.validateEnvelope(foreign, tampered),
        ValidationOutcome.ownershipMismatch,
      );
    });

    test('tampering the account id after signing yields invalidSignature', () {
      final envelope = validator.createEnvelope(ownedClaim());
      const moved = AccountOwnershipClaim(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-2',
        owningUserId: 'user-42',
      );
      expect(
        validator.validateEnvelope(moved, envelope),
        ValidationOutcome.invalidSignature,
      );
      expect(validator.isNonceUsed(envelope.nonce), isFalse);
    });
  });

  group('nonce deduplication and replay', () {
    test('reusing an accepted envelope is a replayed nonce', () {
      final envelope = validator.createEnvelope(ownedClaim());
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.replayedNonce,
      );
      expect(validator.usedNonceCount, 1);
    });

    test('a freshly signed envelope with a used nonce is replayed', () {
      final first = validator.createEnvelope(ownedClaim());
      expect(
        validator.validateEnvelope(ownedClaim(), first),
        ValidationOutcome.success,
      );
      final replay = signEnvelope(
        claim: ownedClaim(),
        nonce: first.nonce,
        timestamp: first.timestamp,
      );
      expect(
        validator.validateEnvelope(ownedClaim(), replay),
        ValidationOutcome.replayedNonce,
      );
      expect(validator.usedNonceCount, 1);
    });

    test('clearNonceCache allows the nonce to be used again', () {
      final envelope = validator.createEnvelope(ownedClaim());
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
      validator.clearNonceCache();
      expect(validator.usedNonceCount, 0);
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
    });

    test('nonces are unique across generated envelopes', () {
      final nonces = <String>{
        validator.createEnvelope(ownedClaim()).nonce,
        validator.createEnvelope(ownedClaim()).nonce,
        validator.createEnvelope(ownedClaim()).nonce,
      };
      expect(nonces.length, 3);
    });
  });

  group('timestamp validity window', () {
    test('timestamp 59 seconds in the past is still valid', () {
      final envelope = validator.createEnvelope(ownedClaim());
      current = base.add(const Duration(seconds: 59));
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
    });

    test('timestamp exactly 60 seconds in the past is at the boundary', () {
      final envelope = validator.createEnvelope(ownedClaim());
      current = base.add(const Duration(seconds: 60));
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
    });

    test('timestamp 61 seconds in the past is expired', () {
      final envelope = validator.createEnvelope(ownedClaim());
      current = base.add(const Duration(seconds: 61));
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.expiredTimestamp,
      );
      expect(validator.isNonceUsed(envelope.nonce), isFalse);
    });

    test('timestamp one hour in the past is expired', () {
      final envelope = validator.createEnvelope(ownedClaim());
      current = base.add(const Duration(hours: 1));
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.expiredTimestamp,
      );
    });

    test('timestamp 4 seconds in the future is within tolerance', () {
      current = base.add(const Duration(seconds: 4));
      final envelope = validator.createEnvelope(ownedClaim());
      current = base;
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.success,
      );
    });

    test('timestamp 6 seconds in the future is rejected', () {
      current = base.add(const Duration(seconds: 6));
      final envelope = validator.createEnvelope(ownedClaim());
      current = base;
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.futureTimestamp,
      );
      expect(validator.isNonceUsed(envelope.nonce), isFalse);
    });
  });

  group('canonical payload and HMAC signature', () {
    test('canonical payload uses a stable alphabetical field order', () {
      final payload = validator.buildCanonicalPayload(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-1',
        nonce: 'nonce-00000001',
        timestamp: base,
        keyId: 'key-1',
      );
      expect(
        payload,
        'accountId=acc-1&keyId=key-1&nonce=nonce-00000001&'
        'timestamp=2026-01-01T12:00:00.000Z&userId=user-42',
      );
    });

    test('absent keyId is encoded as an empty field', () {
      final payload = validator.buildCanonicalPayload(
        authenticatedUserId: 'user-42',
        requestedAccountId: 'acc-1',
        nonce: 'n',
        timestamp: base,
      );
      expect(payload.contains('keyId=&'), isTrue);
    });

    test('signature is a deterministic 64 character lowercase hex digest', () {
      const payload = 'accountId=acc-1&userId=user-42';
      final first = validator.computeSignature(payload);
      final second = validator.computeSignature(payload);
      expect(first, second);
      expect(first.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(first), isTrue);
    });

    test('verifySignature accepts the correct signature', () {
      const payload = 'accountId=acc-1&userId=user-42';
      final signature = validator.computeSignature(payload);
      expect(validator.verifySignature(payload, signature), isTrue);
    });

    test('verifySignature rejects a tampered payload', () {
      const payload = 'accountId=acc-1&userId=user-42';
      final signature = validator.computeSignature(payload);
      expect(
        validator.verifySignature('accountId=acc-2&userId=user-42', signature),
        isFalse,
      );
    });

    test('verifySignature rejects a tampered signature', () {
      const payload = 'accountId=acc-1&userId=user-42';
      expect(validator.verifySignature(payload, 'deadbeef'), isFalse);
    });

    test('tampering the signature on an envelope fails validation', () {
      final envelope = validator.createEnvelope(ownedClaim());
      final tampered = envelope.copyWith(signature: 'deadbeef');
      expect(
        validator.validateEnvelope(ownedClaim(), tampered),
        ValidationOutcome.invalidSignature,
      );
    });

    test('verifySignature is length safe on mismatched lengths', () {
      const payload = 'accountId=acc-1&userId=user-42';
      final signature = validator.computeSignature(payload);
      expect(validator.verifySignature(payload, '$signature extra'), isFalse);
    });
  });

  group('malformed envelope', () {
    test('empty nonce is malformed', () {
      final envelope = HmacSecurityEnvelope(
        nonce: '',
        timestamp: base,
        signature: validator.computeSignature('anything'),
      );
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.malformedEnvelope,
      );
    });

    test('empty signature is malformed', () {
      final envelope = HmacSecurityEnvelope(
        nonce: 'nonce-00000001',
        timestamp: base,
        signature: '',
      );
      expect(
        validator.validateEnvelope(ownedClaim(), envelope),
        ValidationOutcome.malformedEnvelope,
      );
    });
  });

  group('secure nonce generator', () {
    test('default generator produces unique 32 character hex nonces', () {
      final generated = <String>{
        AccountSecurityValidator.generateSecureNonce(),
        AccountSecurityValidator.generateSecureNonce(),
        AccountSecurityValidator.generateSecureNonce(),
      };
      expect(generated.length, 3);
      for (final nonce in generated) {
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nonce), isTrue);
      }
    });

    test('validator exposes the injected nonce sequence', () {
      expect(validator.generateNonce(), 'nonce-00000001');
      expect(validator.generateNonce(), 'nonce-00000002');
    });

    test('generateTimestamp returns the injected UTC time', () {
      current = base.add(const Duration(seconds: 7));
      expect(validator.generateTimestamp(), base.add(const Duration(seconds: 7)));
    });
  });

  group('ValidationOutcome metadata', () {
    test('success is the only valid outcome', () {
      for (final outcome in ValidationOutcome.values) {
        expect(outcome.isValid, outcome == ValidationOutcome.success);
      }
    });

    test('messages are non-empty and emoji free', () {
      for (final outcome in ValidationOutcome.values) {
        expect(outcome.message.isNotEmpty, isTrue);
        expect(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true)
              .hasMatch(outcome.message),
          isFalse,
        );
      }
    });
  });
}
