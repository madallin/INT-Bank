import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/cards/services/virtual_card_service.dart';

VirtualCard buildCard({
  String id = 'card-1',
  String cardNumber = '4242424242424242',
  String cardHolderName = 'Test Holder',
  int expiryMonth = 12,
  int expiryYear = 2030,
  VirtualCardType type = VirtualCardType.multiUseVirtual,
  CardStatus status = CardStatus.active,
  double spendingLimit = 1000.0,
  double spentThisPeriod = 0.0,
}) {
  return VirtualCard(
    id: id,
    cardNumber: cardNumber,
    cardHolderName: cardHolderName,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    type: type,
    status: status,
    spendingLimit: spendingLimit,
    spentThisPeriod: spentThisPeriod,
  );
}

void main() {
  const VirtualCardService service = VirtualCardService();
  const String secret = 'unit-test-card-secret';

  group('SHA-256 known-answer vectors', () {
    test('hashes the ascii string abc', () {
      expect(
        VirtualCardService.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('hashes the empty string', () {
      expect(
        VirtualCardService.sha256Hex(utf8.encode('')),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });

  group('HMAC-SHA256 known-answer vector', () {
    test('matches RFC 4231 twenty byte 0x0b key over Hi There', () {
      final List<int> key = List<int>.filled(20, 0x0b);
      expect(
        VirtualCardService.hmacSha256Hex(key, utf8.encode('Hi There')),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });
  });

  group('computeDynamicCvv', () {
    final DateTime base = DateTime.utc(2026, 6, 15, 10, 30, 0);

    test('is deterministic for the same secret and instant', () {
      final DynamicCvvState first = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: base,
      );
      final DynamicCvvState second = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: base,
      );
      expect(first.currentCvv, second.currentCvv);
      expect(first.totalPeriodSeconds, 300);
    });

    test('produces exactly three numeric characters', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: base,
      );
      expect(state.currentCvv.length, 3);
      expect(RegExp(r'^[0-9]{3}$').hasMatch(state.currentCvv), isTrue);
      expect(int.tryParse(state.currentCvv), isNotNull);
    });

    test('changes value on the next counter step', () {
      final String current = service
          .computeDynamicCvv(cardSecret: secret, currentTime: base)
          .currentCvv;
      final String next = service
          .computeDynamicCvv(
            cardSecret: secret,
            currentTime: base.add(const Duration(seconds: 300)),
          )
          .currentCvv;
      expect(next, isNot(current));
    });

    test('honours a custom period length', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: base,
        periodSeconds: 60,
      );
      expect(state.totalPeriodSeconds, 60);
    });

    test('rejects a non-positive period', () {
      expect(
        () => service.computeDynamicCvv(
          cardSecret: secret,
          currentTime: base,
          periodSeconds: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('secondsRemaining', () {
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    test('is the full period at an exact multiple', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: epoch,
      );
      expect(state.secondsRemaining, 300);
      expect(state.totalPeriodSeconds, 300);
    });

    test('counts down at an offset within the period', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: epoch.add(const Duration(seconds: 150)),
      );
      expect(state.secondsRemaining, 150);
    });

    test('is one second at the end of the period', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: epoch.add(const Duration(seconds: 299)),
      );
      expect(state.secondsRemaining, 1);
    });

    test('resets to the full period on the next step', () {
      final DynamicCvvState state = service.computeDynamicCvv(
        cardSecret: secret,
        currentTime: epoch.add(const Duration(seconds: 300)),
      );
      expect(state.secondsRemaining, 300);
    });
  });

  group('verifyCvv drift window', () {
    final DateTime base = DateTime.utc(2026, 5, 10, 8, 15, 0);

    String cvvAt(DateTime time) => service
        .computeDynamicCvv(cardSecret: secret, currentTime: time)
        .currentCvv;

    test('accepts the current step CVV', () {
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: cvvAt(base),
          currentTime: base,
        ),
        isTrue,
      );
    });

    test('accepts the previous step CVV with window one', () {
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: cvvAt(base.subtract(const Duration(seconds: 300))),
          currentTime: base,
        ),
        isTrue,
      );
    });

    test('accepts the next step CVV with window one', () {
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: cvvAt(base.add(const Duration(seconds: 300))),
          currentTime: base,
        ),
        isTrue,
      );
    });

    test('rejects a CVV two steps away with window one', () {
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: cvvAt(base.subtract(const Duration(seconds: 600))),
          currentTime: base,
          window: 1,
        ),
        isFalse,
      );
    });

    test('accepts a CVV two steps away with window two', () {
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: cvvAt(base.subtract(const Duration(seconds: 600))),
          currentTime: base,
          window: 2,
        ),
        isTrue,
      );
    });

    test('rejects an arbitrary candidate value', () {
      final String current = cvvAt(base);
      final String next = cvvAt(base.add(const Duration(seconds: 300)));
      final String previous =
          cvvAt(base.subtract(const Duration(seconds: 300)));
      String other = '000';
      for (int i = 0; i < 1000; i++) {
        final String candidate = i.toString().padLeft(3, '0');
        if (candidate != current &&
            candidate != next &&
            candidate != previous) {
          other = candidate;
          break;
        }
      }
      expect(
        service.verifyCvv(
          cardSecret: secret,
          candidateCvv: other,
          currentTime: base,
        ),
        isFalse,
      );
    });
  });

  group('isValidPan (Luhn)', () {
    test('accepts a valid PAN', () {
      expect(service.isValidPan('4242424242424242'), isTrue);
    });

    test('accepts a valid PAN with spaces', () {
      expect(service.isValidPan('4242 4242 4242 4242'), isTrue);
    });

    test('accepts a valid PAN with dashes', () {
      expect(service.isValidPan('4242-4242-4242-4242'), isTrue);
    });

    test('rejects a PAN with a failing checksum', () {
      expect(service.isValidPan('4242424242424241'), isFalse);
    });

    test('rejects empty and non-numeric input', () {
      expect(service.isValidPan(''), isFalse);
      expect(service.isValidPan('abcd'), isFalse);
    });
  });

  group('maskPan', () {
    test('masks all but the final four digits', () {
      expect(service.maskPan('4242424242424242'), '**** **** **** 4242');
    });

    test('masks a spaced PAN', () {
      expect(service.maskPan('4242 4242 4242 4242'), '**** **** **** 4242');
    });
  });

  group('model helpers', () {
    test('isActive reflects the status field', () {
      expect(buildCard(status: CardStatus.active).isActive, isTrue);
      expect(buildCard(status: CardStatus.frozen).isActive, isFalse);
    });

    test('isExpiredAt honours the expiry month boundary', () {
      final VirtualCard card = buildCard(expiryMonth: 12, expiryYear: 2026);
      expect(card.isExpiredAt(DateTime.utc(2026, 12, 31)), isFalse);
      expect(card.isExpiredAt(DateTime.utc(2027, 1, 1)), isTrue);
    });

    test('copyWith preserves unspecified fields', () {
      final VirtualCard card = buildCard();
      final VirtualCard updated = card.copyWith(status: CardStatus.frozen);
      expect(updated.status, CardStatus.frozen);
      expect(updated.id, card.id);
      expect(updated.spendingLimit, card.spendingLimit);
    });
  });

  group('disposable single use card', () {
    final DateTime now = DateTime.utc(2026, 6, 1);

    test('authorizes before use and burns after the transaction', () {
      final VirtualCard card = buildCard(
        type: VirtualCardType.disposableSingleUse,
        spendingLimit: 1000.0,
      );
      expect(service.canAuthorizeTransaction(card, 100.0, now: now), isTrue);
      final VirtualCard burned =
          service.authorizeTransaction(card, 100.0, now: now);
      expect(burned.status, CardStatus.burned);
      expect(burned.spentThisPeriod, closeTo(100.0, 0.001));
    });

    test('cannot authorize or transact once burned', () {
      final VirtualCard card = buildCard(
        type: VirtualCardType.disposableSingleUse,
      );
      final VirtualCard burned =
          service.authorizeTransaction(card, 10.0, now: now);
      expect(service.canAuthorizeTransaction(burned, 5.0, now: now), isFalse);
      expect(
        () => service.authorizeTransaction(burned, 5.0, now: now),
        throwsStateError,
      );
    });

    test('burnDisposableCard moves a disposable card to burned', () {
      final VirtualCard card = buildCard(
        type: VirtualCardType.disposableSingleUse,
      );
      expect(service.burnDisposableCard(card).status, CardStatus.burned);
    });

    test('burnDisposableCard leaves multi-use cards unchanged', () {
      final VirtualCard card = buildCard(type: VirtualCardType.multiUseVirtual);
      expect(service.burnDisposableCard(card).status, CardStatus.active);
    });
  });

  group('multi-use virtual card lifecycle', () {
    final DateTime now = DateTime.utc(2026, 6, 1);

    test('freeze blocks authorization and unfreeze restores it', () {
      final VirtualCard card = buildCard(spendingLimit: 1000.0);
      final VirtualCard frozen = service.freezeCard(card);
      expect(frozen.status, CardStatus.frozen);
      expect(service.canAuthorizeTransaction(frozen, 10.0, now: now), isFalse);
      final VirtualCard unfrozen = service.unfreezeCard(frozen);
      expect(unfrozen.status, CardStatus.active);
      expect(service.canAuthorizeTransaction(unfrozen, 10.0, now: now), isTrue);
    });

    test('authorized transactions accumulate spentThisPeriod', () {
      final VirtualCard first =
          service.authorizeTransaction(buildCard(), 100.0, now: now);
      final VirtualCard second =
          service.authorizeTransaction(first, 50.0, now: now);
      expect(second.spentThisPeriod, closeTo(150.0, 0.001));
      expect(second.status, CardStatus.active);
    });

    test('freeze only applies from active', () {
      final VirtualCard frozen = buildCard(status: CardStatus.frozen);
      expect(service.freezeCard(frozen).status, CardStatus.frozen);
    });

    test('unfreeze only applies from frozen', () {
      final VirtualCard active = buildCard(status: CardStatus.active);
      expect(service.unfreezeCard(active).status, CardStatus.active);
    });
  });

  group('spending limit and expiry', () {
    final DateTime now = DateTime.utc(2026, 6, 1);

    test('allows a transaction exactly at the limit', () {
      final VirtualCard card = buildCard(spendingLimit: 100.0);
      expect(service.canAuthorizeTransaction(card, 100.0, now: now), isTrue);
      final VirtualCard updated =
          service.authorizeTransaction(card, 100.0, now: now);
      expect(updated.spentThisPeriod, closeTo(100.0, 0.001));
      expect(service.canAuthorizeTransaction(updated, 0.01, now: now), isFalse);
    });

    test('rejects an amount above the remaining limit', () {
      final VirtualCard card = buildCard(spendingLimit: 100.0);
      expect(service.canAuthorizeTransaction(card, 100.01, now: now), isFalse);
      expect(
        () => service.authorizeTransaction(card, 100.01, now: now),
        throwsStateError,
      );
    });

    test('rejects zero and negative amounts', () {
      final VirtualCard card = buildCard(spendingLimit: 100.0);
      expect(service.canAuthorizeTransaction(card, 0.0, now: now), isFalse);
      expect(service.canAuthorizeTransaction(card, -5.0, now: now), isFalse);
    });

    test('rejects an expired card', () {
      final VirtualCard card = buildCard(expiryMonth: 12, expiryYear: 2025);
      expect(card.isExpiredAt(now), isTrue);
      expect(service.canAuthorizeTransaction(card, 10.0, now: now), isFalse);
      expect(
        () => service.authorizeTransaction(card, 10.0, now: now),
        throwsStateError,
      );
    });

    test('rejects a frozen card regardless of amount', () {
      final VirtualCard card = buildCard(status: CardStatus.frozen);
      expect(service.canAuthorizeTransaction(card, 10.0, now: now), isFalse);
    });
  });
}
