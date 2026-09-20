import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/cards/services/wallet_provisioning_service.dart';

class FakeWalletPlatformBridge implements WalletPlatformBridge {
  FakeWalletPlatformBridge({
    this.appleSupported = true,
    this.googleSupported = true,
    List<String>? tokens,
  }) : _tokens = <String>[...?tokens];

  bool appleSupported;
  bool googleSupported;
  final List<String> _tokens;

  @override
  bool supportsApplePay() => appleSupported;

  @override
  bool supportsGoogleWallet() => googleSupported;

  @override
  List<String> provisionedCardTokens() => List<String>.from(_tokens);
}

void main() {
  group('checkEligibility', () {
    test('returns unsupportedDevice when the device lacks the wallet', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(appleSupported: false),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        isCardEligible: true,
      );
      expect(result.status, WalletEligibilityStatus.unsupportedDevice);
      expect(result.walletType, WalletType.applePay);
      expect(result.cardId, 'card-1');
      expect(result.isEligible, isFalse);
    });

    test('returns alreadyAdded when the card token is provisioned', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(tokens: <String>['card-1']),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.googleWallet,
        cardId: 'card-1',
        isCardEligible: true,
      );
      expect(result.status, WalletEligibilityStatus.alreadyAdded);
      expect(result.isEligible, isFalse);
    });

    test('returns cardNotEligible when the card cannot be provisioned', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        isCardEligible: false,
      );
      expect(result.status, WalletEligibilityStatus.cardNotEligible);
      expect(result.isEligible, isFalse);
    });

    test('returns eligible when supported, not added and card eligible', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.googleWallet,
        cardId: 'card-1',
        isCardEligible: true,
      );
      expect(result.status, WalletEligibilityStatus.eligible);
      expect(result.isEligible, isTrue);
    });

    test('prefers unsupportedDevice over alreadyAdded', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(
          appleSupported: false,
          tokens: <String>['card-1'],
        ),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        isCardEligible: false,
      );
      expect(result.status, WalletEligibilityStatus.unsupportedDevice);
    });

    test('prefers alreadyAdded over cardNotEligible', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(tokens: <String>['card-1']),
      );
      final WalletEligibility result = service.checkEligibility(
        walletType: WalletType.googleWallet,
        cardId: 'card-1',
        isCardEligible: false,
      );
      expect(result.status, WalletEligibilityStatus.alreadyAdded);
    });
  });

  group('buildProvisioningPayload', () {
    final DateTime generatedAt = DateTime.utc(2026, 6, 15, 10, 30, 0);

    test('uses the Apple payload version for applePay', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletProvisioningPayload payload =
          service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      expect(payload.payloadVersion, 'PKAddPasses.v1');
      expect(payload.walletType, WalletType.applePay);
      expect(payload.deviceAccountIdentifier, 'device-abc');
    });

    test('uses the Google payload version for googleWallet', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletProvisioningPayload payload =
          service.buildProvisioningPayload(
        walletType: WalletType.googleWallet,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      expect(payload.payloadVersion, 'TAP_AND_PAY.v2');
      expect(payload.walletType, WalletType.googleWallet);
    });

    test('is deterministic for a fixed timestamp', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletProvisioningPayload first = service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      final WalletProvisioningPayload second = service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      expect(first, second);
      expect(first.nonce, second.nonce);
      expect(first.ephemeralPublicKey, second.ephemeralPublicKey);
      expect(first.encryptedCardData, second.encryptedCardData);
      expect(first.hashCode, second.hashCode);
    });

    test('differs across timestamps', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletProvisioningPayload first = service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      final WalletProvisioningPayload second = service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt.add(const Duration(seconds: 1)),
      );
      expect(first, isNot(second));
      expect(first.nonce, isNot(second.nonce));
    });

    test('derives nonce and ephemeral key of the expected lengths', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final WalletProvisioningPayload payload =
          service.buildProvisioningPayload(
        walletType: WalletType.googleWallet,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      expect(payload.nonce.length, 16);
      expect(payload.ephemeralPublicKey.length, 32);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(payload.nonce), isTrue);
      expect(
        RegExp(r'^[0-9a-f]{32}$').hasMatch(payload.ephemeralPublicKey),
        isTrue,
      );
      expect(payload.encryptedCardData, isNotEmpty);
    });

    test('material is derived from the SHA-256 digest inputs', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      final String material = 'card-1|device-abc|'
          '${generatedAt.toUtc().toIso8601String()}|${WalletType.applePay}';
      final String hash =
          WalletProvisioningService.sha256Hex(utf8.encode(material));
      final WalletProvisioningPayload payload =
          service.buildProvisioningPayload(
        walletType: WalletType.applePay,
        cardId: 'card-1',
        deviceAccountIdentifier: 'device-abc',
        generatedAt: generatedAt,
      );
      expect(payload.nonce, hash.substring(0, 16));
      expect(payload.ephemeralPublicKey, hash.substring(16, 48));
      expect(payload.encryptedCardData, hash.substring(48));
    });
  });

  group('provisioned wallet state', () {
    test('starts empty', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      expect(service.provisionedWallets, isEmpty);
    });

    test('records provisioned wallets', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      service.recordProvisioned(WalletType.applePay, 'card-1');
      service.recordProvisioned(WalletType.googleWallet, 'card-2');
      expect(service.provisionedWallets.length, 2);
      expect(
        service.provisionedWallets.contains('${WalletType.applePay.name}:card-1'),
        isTrue,
      );
      expect(
        service.provisionedWallets
            .contains('${WalletType.googleWallet.name}:card-2'),
        isTrue,
      );
    });

    test('does not record the same wallet card twice', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      service.recordProvisioned(WalletType.applePay, 'card-1');
      service.recordProvisioned(WalletType.applePay, 'card-1');
      expect(service.provisionedWallets.length, 1);
    });

    test('returns an unmodifiable view of provisioned wallets', () {
      final WalletProvisioningService service = WalletProvisioningService(
        FakeWalletPlatformBridge(),
      );
      service.recordProvisioned(WalletType.applePay, 'card-1');
      expect(
        () => service.provisionedWallets.add('mutated'),
        throwsUnsupportedError,
      );
    });
  });

  group('model equality', () {
    test('WalletEligibility supports value equality', () {
      const WalletEligibility first = WalletEligibility(
        status: WalletEligibilityStatus.eligible,
        walletType: WalletType.applePay,
        cardId: 'card-1',
      );
      const WalletEligibility second = WalletEligibility(
        status: WalletEligibilityStatus.eligible,
        walletType: WalletType.applePay,
        cardId: 'card-1',
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('card-1'));
    });
  });
}
