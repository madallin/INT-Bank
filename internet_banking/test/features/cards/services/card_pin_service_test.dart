import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/cards/services/card_pin_service.dart';

void main() {
  final DateTime base = DateTime.utc(2026, 6, 15, 10, 30, 0);

  group('isWeakPin', () {
    test('rejects every blocklisted PIN', () {
      final CardPinService service = CardPinService();
      const List<String> blocked = <String>[
        '0000',
        '1111',
        '2222',
        '1234',
        '4321',
        '1212',
        '0101',
        '1122',
        '6969',
        '1010',
      ];
      for (final String pin in blocked) {
        expect(service.isWeakPin(pin), isTrue, reason: 'expected $pin weak');
      }
    });

    test('rejects repeated digits', () {
      final CardPinService service = CardPinService();
      expect(service.isWeakPin('7777'), isTrue);
      expect(service.isWeakPin('9999'), isTrue);
    });

    test('rejects ascending consecutive sequences', () {
      final CardPinService service = CardPinService();
      expect(service.isWeakPin('0123'), isTrue);
      expect(service.isWeakPin('5678'), isTrue);
      expect(service.isWeakPin('6789'), isTrue);
    });

    test('rejects descending consecutive sequences', () {
      final CardPinService service = CardPinService();
      expect(service.isWeakPin('9876'), isTrue);
      expect(service.isWeakPin('7654'), isTrue);
      expect(service.isWeakPin('3210'), isTrue);
    });

    test('rejects non-four-digit input', () {
      final CardPinService service = CardPinService();
      expect(service.isWeakPin(''), isTrue);
      expect(service.isWeakPin('123'), isTrue);
      expect(service.isWeakPin('12345'), isTrue);
      expect(service.isWeakPin('abcd'), isTrue);
      expect(service.isWeakPin('12a4'), isTrue);
    });

    test('accepts strong PINs', () {
      final CardPinService service = CardPinService();
      expect(service.isWeakPin('5839'), isFalse);
      expect(service.isWeakPin('2468'), isFalse);
      expect(service.isWeakPin('9182'), isFalse);
    });
  });

  group('changePin', () {
    test('blocked when biometric is not verified', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinChangeResult result = service.changePin(
        oldPin: '5839',
        newPin: '7413',
        confirmPin: '7413',
        biometricVerified: false,
      );
      expect(result, PinChangeResult.blocked);
      expect(service.storedPin, '5839');
    });

    test('pinMismatch when confirmation differs', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinChangeResult result = service.changePin(
        oldPin: '5839',
        newPin: '7413',
        confirmPin: '7414',
        biometricVerified: true,
      );
      expect(result, PinChangeResult.pinMismatch);
      expect(service.storedPin, '5839');
    });

    test('weakPin when the candidate is weak', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinChangeResult result = service.changePin(
        oldPin: '5839',
        newPin: '1234',
        confirmPin: '1234',
        biometricVerified: true,
      );
      expect(result, PinChangeResult.weakPin);
      expect(service.storedPin, '5839');
    });

    test('mismatch check takes precedence over weak candidate', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinChangeResult result = service.changePin(
        oldPin: '5839',
        newPin: '0000',
        confirmPin: '0001',
        biometricVerified: true,
      );
      expect(result, PinChangeResult.pinMismatch);
      expect(service.storedPin, '5839');
    });

    test('succeeds and mutates the stored PIN for strong input', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinChangeResult result = service.changePin(
        oldPin: '5839',
        newPin: '7413',
        confirmPin: '7413',
        biometricVerified: true,
      );
      expect(result, PinChangeResult.success);
      expect(service.storedPin, '7413');
      final PinRevealResult reveal =
          service.revealPin(biometricVerified: true, now: base);
      expect(reveal.state?.pin, '7413');
    });
  });

  group('revealPin biometric enforcement', () {
    test('requires biometric on the first failure', () {
      final CardPinService service = CardPinService();
      final PinRevealResult result =
          service.revealPin(biometricVerified: false, now: base);
      expect(result.isSuccess, isFalse);
      expect(result.state, isNull);
      expect(result.failure, PinRevealFailure.biometricRequired);
    });

    test('reports biometricFailed on later failures', () {
      final CardPinService service = CardPinService();
      service.revealPin(biometricVerified: false, now: base);
      final PinRevealResult second =
          service.revealPin(biometricVerified: false, now: base);
      expect(second.failure, PinRevealFailure.biometricFailed);
    });

    test('locks with tooManyAttempts after three failures', () {
      final CardPinService service = CardPinService();
      service.revealPin(biometricVerified: false, now: base);
      service.revealPin(biometricVerified: false, now: base);
      service.revealPin(biometricVerified: false, now: base);
      final PinRevealResult locked =
          service.revealPin(biometricVerified: false, now: base);
      expect(locked.failure, PinRevealFailure.tooManyAttempts);
    });

    test('successful reveal resets the failure counter', () {
      final CardPinService service = CardPinService();
      service.revealPin(biometricVerified: false, now: base);
      service.revealPin(biometricVerified: false, now: base);
      final PinRevealResult success =
          service.revealPin(biometricVerified: true, now: base);
      expect(success.isSuccess, isTrue);
      final PinRevealResult afterReset =
          service.revealPin(biometricVerified: false, now: base);
      expect(afterReset.failure, PinRevealFailure.biometricRequired);
    });
  });

  group('revealPin state', () {
    test('produces a visible PIN within the window', () {
      final CardPinService service = CardPinService(initialPin: '5839');
      final PinRevealResult result =
          service.revealPin(biometricVerified: true, now: base);
      final PinRevealState? state = result.state;
      expect(state, isNotNull);
      expect(state!.pin, '5839');
      expect(state.revealedAt, base);
      expect(
        state.expiresAt,
        base.add(const Duration(seconds: CardPinService.revealWindowSeconds)),
      );
      expect(state.isVisibleAt(base), isTrue);
      expect(state.isVisibleAt(base.add(const Duration(seconds: 9))), isTrue);
      expect(state.maskedPin, '****');
    });
  });

  group('concealIfExpired', () {
    PinRevealState reveal(CardPinService service) {
      return service.revealPin(biometricVerified: true, now: base).state!;
    }

    test('keeps the same state strictly before expiry', () {
      final CardPinService service = CardPinService();
      final PinRevealState state = reveal(service);
      final PinRevealState kept = service.concealIfExpired(
        state,
        base.add(const Duration(seconds: 9)),
      );
      expect(identical(kept, state), isTrue);
      expect(kept.pin, isNotNull);
    });

    test('conceals exactly at the expiresAt boundary', () {
      final CardPinService service = CardPinService();
      final PinRevealState state = reveal(service);
      final PinRevealState concealed = service.concealIfExpired(
        state,
        base.add(const Duration(seconds: 10)),
      );
      expect(concealed.pin, isNull);
      expect(concealed.maskedPin, '');
      expect(concealed.isVisibleAt(base.add(const Duration(seconds: 10))),
          isFalse);
    });

    test('conceals after the window has elapsed', () {
      final CardPinService service = CardPinService();
      final PinRevealState state = reveal(service);
      final PinRevealState concealed = service.concealIfExpired(
        state,
        base.add(const Duration(seconds: 30)),
      );
      expect(concealed.pin, isNull);
      expect(concealed.revealedAt, state.revealedAt);
      expect(concealed.expiresAt, state.expiresAt);
    });

    test('conceal clears the PIN and is idempotent', () {
      final CardPinService service = CardPinService();
      final PinRevealState state = reveal(service);
      final PinRevealState concealed = service.conceal(state);
      expect(concealed.pin, isNull);
      expect(identical(service.conceal(concealed), concealed), isTrue);
    });
  });

  group('PinRevealState model', () {
    test('equality and hashCode follow field values', () {
      final DateTime t = base.add(const Duration(seconds: 10));
      final PinRevealState first = PinRevealState(
        pin: '5839',
        revealedAt: base,
        expiresAt: t,
      );
      final PinRevealState second = PinRevealState(
        pin: '5839',
        revealedAt: base,
        expiresAt: t,
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('concealed state hides the mask and is not visible', () {
      final PinRevealState state = PinRevealState(
        pin: null,
        revealedAt: base,
        expiresAt: base.add(const Duration(seconds: 10)),
      );
      expect(state.maskedPin, '');
      expect(state.isVisibleAt(base), isFalse);
    });
  });

  group('PinRevealResult model', () {
    test('a failure result carries no state', () {
      const PinRevealResult failure = PinRevealResult.failure(
        PinRevealFailure.biometricRequired,
      );
      expect(failure.state, isNull);
      expect(failure.failure, PinRevealFailure.biometricRequired);
      expect(failure.isSuccess, isFalse);
    });
  });
}
