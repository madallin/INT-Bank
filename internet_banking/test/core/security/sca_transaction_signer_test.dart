import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/sca_transaction_signer.dart';

void main() {
  const List<int> secretKey = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  const String iban = 'RO49AAAA1B31007593840000';

  late DateTime current;
  DateTime clock() => current;

  late ScaTransactionSigner signer;
  late ScaChallenge challenge;

  setUp(() {
    current = DateTime.utc(2026, 1, 1, 12, 0, 0);
    signer = ScaTransactionSigner(secretKey: secretKey, clock: clock);
    challenge = signer.createChallenge(
      userId: 'user-42',
      recipientIban: iban,
      amountInMinorUnits: 5000,
      currency: 'EUR',
    );
  });

  group('requiresDynamicLinking', () {
    test('3000 minor units is at threshold and does not require linking', () {
      expect(signer.requiresDynamicLinking(3000), isFalse);
    });

    test('3001 minor units requires linking', () {
      expect(signer.requiresDynamicLinking(3001), isTrue);
    });

    test('small amount requires linking when beneficiary is new', () {
      expect(signer.requiresDynamicLinking(100, isNewBeneficiary: true), isTrue);
    });

    test('zero amount without new beneficiary does not require linking', () {
      expect(signer.requiresDynamicLinking(0), isFalse);
    });

    test('new beneficiary at threshold boundary requires linking', () {
      expect(
        signer.requiresDynamicLinking(3000, isNewBeneficiary: true),
        isTrue,
      );
    });
  });

  group('challenge generation', () {
    test('expiry uses injected clock plus ttl', () {
      expect(challenge.createdAt, DateTime.utc(2026, 1, 1, 12, 0, 0));
      expect(
        challenge.expiresAt,
        DateTime.utc(2026, 1, 1, 12, 5, 0),
      );
    });

    test('same inputs with fixed clock produce stable id and code', () {
      final first = signer.createChallenge(
        userId: 'user-42',
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      final second = signer.createChallenge(
        userId: 'user-42',
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(first.challengeId, second.challengeId);
      expect(first.authenticationCode, second.authenticationCode);
    });

    test('different amount produces different authentication code', () {
      final other = signer.createChallenge(
        userId: 'user-42',
        recipientIban: iban,
        amountInMinorUnits: 5001,
        currency: 'EUR',
      );
      expect(other.authenticationCode, isNot(challenge.authenticationCode));
    });

    test('challenge retains metadata', () {
      expect(challenge.userId, 'user-42');
      expect(challenge.amountInMinorUnits, 5000);
      expect(challenge.currency, 'EUR');
      expect(challenge.isNewBeneficiary, isFalse);
    });
  });

  group('verification', () {
    test('exact transaction values are approved', () {
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.approved);
      expect(result.valid, isTrue);
      expect(result.isApproved, isTrue);
      expect(result.challengeId, challenge.challengeId);
    });
  });

  group('tamper proof', () {
    test('amount plus one minor unit is tampered', () {
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5001,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.tampered);
      expect(result.valid, isFalse);
    });

    test('amount minus one minor unit is tampered', () {
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 4999,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.tampered);
      expect(result.valid, isFalse);
    });

    test('single IBAN character change is tampered', () {
      const altered = 'RO49AAAA1B31007593840001';
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: altered,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.tampered);
      expect(result.valid, isFalse);
      expect(result.challengeId, challenge.challengeId);
    });

    test('currency change is tampered', () {
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'USD',
      );
      expect(result.status, ScaStatus.tampered);
      expect(result.valid, isFalse);
    });

    test('recomputed code for modified values differs from stored code', () {
      final original = signer.computeAuthenticationCode(
        challengeId: challenge.challengeId,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      final modified = signer.computeAuthenticationCode(
        challengeId: challenge.challengeId,
        recipientIban: iban,
        amountInMinorUnits: 5001,
        currency: 'EUR',
      );
      expect(original, challenge.authenticationCode);
      expect(modified, isNot(challenge.authenticationCode));
    });

    test('tampered amount does not match stored code', () {
      final modifiedIban = signer.computeAuthenticationCode(
        challengeId: challenge.challengeId,
        recipientIban: 'RO49AAAA1B31007593840001',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(modifiedIban, isNot(challenge.authenticationCode));
    });
  });

  group('expiry', () {
    test('verification after ttl is expired', () {
      current = DateTime.utc(2026, 1, 1, 12, 5, 1);
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.expired);
      expect(result.valid, isFalse);
    });

    test('verification exactly at expiry boundary is still valid', () {
      current = DateTime.utc(2026, 1, 1, 12, 5, 0);
      final result = signer.verifyAuthorization(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.approved);
    });
  });

  group('authorize', () {
    test('user rejection yields rejected', () {
      final result = signer.authorize(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
        userApproved: false,
      );
      expect(result.status, ScaStatus.rejected);
      expect(result.valid, isFalse);
      expect(result.isRejected, isTrue);
    });

    test('user approval delegates to verification', () {
      final result = signer.authorize(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.approved);
      expect(result.valid, isTrue);
    });

    test('user approval with tampered amount is still tampered', () {
      final result = signer.authorize(
        challenge,
        recipientIban: iban,
        amountInMinorUnits: 5001,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.tampered);
    });
  });

  group('IBAN normalization', () {
    test('spaces and lowercase are accepted', () {
      final spaced = signer.createChallenge(
        userId: 'user-42',
        recipientIban: 'ro49 aaaa 1b31 0075 9384 0000',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      final result = signer.verifyAuthorization(
        spaced,
        recipientIban: 'RO49AAAA1B31007593840000',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.approved);
    });

    test('equivalent formatting produces identical binding', () {
      final spaced = signer.createChallenge(
        userId: 'user-42',
        recipientIban: 'ro49 aaaa 1b31 0075 9384 0000',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      final compact = signer.createChallenge(
        userId: 'user-42',
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(spaced.recipientIban, compact.recipientIban);
      expect(spaced.authenticationCode, compact.authenticationCode);
    });

    test('altered character survives normalization and is tampered', () {
      final spaced = signer.createChallenge(
        userId: 'user-42',
        recipientIban: 'RO49 AAAA 1B31 0075 9384 0000',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      final result = signer.verifyAuthorization(
        spaced,
        recipientIban: 'ro49aaaa1b31007593840001',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(result.status, ScaStatus.tampered);
    });

    test('normalizeIban strips whitespace and uppercases', () {
      expect(signer.normalizeIban(' ro49 aaaa '), 'RO49AAAA');
    });
  });

  group('canonical payload', () {
    test('payload binds id, normalized iban, amount and currency', () {
      final payload = signer.buildCanonicalPayload(
        challengeId: challenge.challengeId,
        recipientIban: 'ro49 aaaa 1b31 0075 9384 0000',
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(payload, '${challenge.challengeId}|$iban|5000|EUR');
    });

    test('authentication code is a 64 char hex sha256 hmac', () {
      final code = signer.computeAuthenticationCode(
        challengeId: 'challenge-1',
        recipientIban: iban,
        amountInMinorUnits: 5000,
        currency: 'EUR',
      );
      expect(code.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(code), isTrue);
      expect(utf8.encode(code).length, 64);
    });
  });
}
