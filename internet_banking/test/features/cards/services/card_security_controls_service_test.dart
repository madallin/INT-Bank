import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/cards/services/card_security_controls_service.dart';

const CardSecurityControlsService service = CardSecurityControlsService();

final DateTime fixedTime = DateTime.utc(2026, 6, 15, 10, 30, 0);

CardTransaction txn({
  CardTransactionChannel channel = CardTransactionChannel.online,
  double amount = 100.0,
  String merchantCountry = 'US',
  DateTime? timestamp,
}) {
  return CardTransaction(
    channel: channel,
    amount: amount,
    merchantCountry: merchantCountry,
    timestamp: timestamp ?? fixedTime,
  );
}

CardSecuritySettings settings({
  bool online = true,
  bool atm = true,
  bool contactless = true,
  bool magstripe = true,
  bool geo = false,
  List<String> countries = const <String>[],
  double atmLimit = 1000.0,
  double onlineLimit = 5000.0,
}) {
  return CardSecuritySettings(
    isOnlinePaymentsEnabled: online,
    isAtmWithdrawalsEnabled: atm,
    isContactlessEnabled: contactless,
    isMagstripeEnabled: magstripe,
    isGeoFencingEnabled: geo,
    allowedCountryCodes: countries,
    dailyAtmAtmLimit: atmLimit,
    dailyOnlineLimit: onlineLimit,
  );
}

AuthorizationDecision evaluate({
  CardSecuritySettings? config,
  CardTransaction? transaction,
  double spentOnline = 0.0,
  double spentAtm = 0.0,
}) {
  return service.evaluateTransaction(
    settings: config ?? settings(),
    transaction: transaction ?? txn(),
    spentOnlineToday: spentOnline,
    spentAtmToday: spentAtm,
  );
}

void main() {
  group('CardSecuritySettings', () {
    test('has sensible defaults', () {
      const CardSecuritySettings defaults = CardSecuritySettings.defaults();
      expect(defaults.isOnlinePaymentsEnabled, isTrue);
      expect(defaults.isAtmWithdrawalsEnabled, isTrue);
      expect(defaults.isContactlessEnabled, isTrue);
      expect(defaults.isMagstripeEnabled, isTrue);
      expect(defaults.isGeoFencingEnabled, isFalse);
      expect(defaults.allowedCountryCodes, isEmpty);
      expect(defaults.dailyAtmAtmLimit, 1000.0);
      expect(defaults.dailyOnlineLimit, 5000.0);
    });

    test('const constructor defaults enable channels and disable geo', () {
      const CardSecuritySettings defaults = CardSecuritySettings();
      expect(defaults.isOnlinePaymentsEnabled, isTrue);
      expect(defaults.isGeoFencingEnabled, isFalse);
    });

    test('copyWith replaces only the supplied fields', () {
      final CardSecuritySettings base = settings(countries: const <String>['US']);
      final CardSecuritySettings updated =
          base.copyWith(isOnlinePaymentsEnabled: false);
      expect(updated.isOnlinePaymentsEnabled, isFalse);
      expect(updated.isAtmWithdrawalsEnabled, base.isAtmWithdrawalsEnabled);
      expect(updated.isContactlessEnabled, base.isContactlessEnabled);
      expect(updated.isMagstripeEnabled, base.isMagstripeEnabled);
      expect(updated.isGeoFencingEnabled, base.isGeoFencingEnabled);
      expect(updated.allowedCountryCodes, base.allowedCountryCodes);
      expect(updated.dailyAtmAtmLimit, base.dailyAtmAtmLimit);
      expect(updated.dailyOnlineLimit, base.dailyOnlineLimit);
    });

    test('copyWith with no arguments produces an equal instance', () {
      final CardSecuritySettings base = settings(geo: true, countries: const <String>['US']);
      expect(base.copyWith(), equals(base));
      expect(base.copyWith().hashCode, base.hashCode);
    });

    test('equality compares every field including the country list', () {
      final CardSecuritySettings a = settings(countries: const <String>['US', 'CA']);
      final CardSecuritySettings b = settings(countries: const <String>['US', 'CA']);
      final CardSecuritySettings c = settings(countries: const <String>['US']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString contains the field values', () {
      final CardSecuritySettings value = settings(onlineLimit: 250.0);
      expect(value.toString(), contains('dailyOnlineLimit: 250.0'));
      expect(value.toString(), contains('geoFencing'));
    });

    test('original instance is unchanged after copyWith', () {
      final CardSecuritySettings original = settings(online: true);
      original.copyWith(isOnlinePaymentsEnabled: false);
      expect(original.isOnlinePaymentsEnabled, isTrue);
    });
  });

  group('CardTransaction', () {
    test('exposes all fields', () {
      final CardTransaction value = txn(
        channel: CardTransactionChannel.atm,
        amount: 42.5,
        merchantCountry: 'DE',
      );
      expect(value.channel, CardTransactionChannel.atm);
      expect(value.amount, 42.5);
      expect(value.merchantCountry, 'DE');
      expect(value.timestamp, fixedTime);
    });

    test('supports value equality and hashCode', () {
      final CardTransaction a = txn();
      final CardTransaction b = txn();
      final CardTransaction c = txn(amount: 5.0);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString contains the channel', () {
      expect(txn().toString(), contains('online'));
    });
  });

  group('channel restrictions', () {
    test('disabled online channel is declined', () {
      expect(
        evaluate(
          config: settings(online: false),
          transaction: txn(channel: CardTransactionChannel.online),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('disabled atm channel is declined', () {
      expect(
        evaluate(
          config: settings(atm: false),
          transaction: txn(channel: CardTransactionChannel.atm),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('disabled contactless channel is declined', () {
      expect(
        evaluate(
          config: settings(contactless: false),
          transaction: txn(channel: CardTransactionChannel.contactless),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('disabled magstripe channel is declined', () {
      expect(
        evaluate(
          config: settings(magstripe: false),
          transaction: txn(channel: CardTransactionChannel.magstripe),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('each enabled channel is approved under the limits', () {
      for (final CardTransactionChannel channel
          in CardTransactionChannel.values) {
        expect(
          evaluate(transaction: txn(channel: channel)),
          AuthorizationDecision.approved,
          reason: 'channel $channel should be approved',
        );
      }
    });

    test('channel disabled takes precedence over an exceeded limit', () {
      expect(
        evaluate(
          config: settings(online: false, onlineLimit: 1.0),
          transaction: txn(channel: CardTransactionChannel.online, amount: 100.0),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('channel disabled takes precedence over a geo block', () {
      expect(
        evaluate(
          config: settings(online: false, geo: true, countries: const <String>['US']),
          transaction:
              txn(channel: CardTransactionChannel.online, merchantCountry: 'JP'),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });
  });

  group('online daily limit', () {
    test('under the limit is approved', () {
      expect(
        evaluate(
          config: settings(onlineLimit: 1000.0),
          transaction: txn(amount: 400.0),
          spentOnline: 500.0,
        ),
        AuthorizationDecision.approved,
      );
    });

    test('exactly at the limit is approved', () {
      expect(
        evaluate(
          config: settings(onlineLimit: 1000.0),
          transaction: txn(amount: 500.0),
          spentOnline: 500.0,
        ),
        AuthorizationDecision.approved,
      );
    });

    test('strictly over the limit is declined', () {
      expect(
        evaluate(
          config: settings(onlineLimit: 1000.0),
          transaction: txn(amount: 500.01),
          spentOnline: 500.0,
        ),
        AuthorizationDecision.declinedLimitExceeded,
      );
    });

    test('approves a transaction exactly equal to an untouched limit', () {
      expect(
        evaluate(
          config: settings(onlineLimit: 1000.0),
          transaction: txn(amount: 1000.0),
        ),
        AuthorizationDecision.approved,
      );
    });

    test('atm spend does not count against the online limit', () {
      expect(
        evaluate(
          config: settings(onlineLimit: 100.0),
          transaction: txn(amount: 100.0),
          spentOnline: 0.0,
          spentAtm: 999.0,
        ),
        AuthorizationDecision.approved,
      );
    });
  });

  group('atm daily limit', () {
    test('under the limit is approved', () {
      expect(
        evaluate(
          config: settings(atmLimit: 500.0),
          transaction:
              txn(channel: CardTransactionChannel.atm, amount: 100.0),
          spentAtm: 300.0,
        ),
        AuthorizationDecision.approved,
      );
    });

    test('exactly at the limit is approved', () {
      expect(
        evaluate(
          config: settings(atmLimit: 500.0),
          transaction:
              txn(channel: CardTransactionChannel.atm, amount: 200.0),
          spentAtm: 300.0,
        ),
        AuthorizationDecision.approved,
      );
    });

    test('strictly over the limit is declined', () {
      expect(
        evaluate(
          config: settings(atmLimit: 500.0),
          transaction:
              txn(channel: CardTransactionChannel.atm, amount: 200.01),
          spentAtm: 300.0,
        ),
        AuthorizationDecision.declinedLimitExceeded,
      );
    });

    test('online spend does not count against the atm limit', () {
      expect(
        evaluate(
          config: settings(atmLimit: 100.0),
          transaction:
              txn(channel: CardTransactionChannel.atm, amount: 100.0),
          spentAtm: 0.0,
          spentOnline: 999.0,
        ),
        AuthorizationDecision.approved,
      );
    });

    test('contactless and magstripe are not limited by the configured caps',
        () {
      expect(
        evaluate(
          config: settings(onlineLimit: 1.0, atmLimit: 1.0),
          transaction: txn(
            channel: CardTransactionChannel.contactless,
            amount: 9999.0,
          ),
          spentOnline: 9999.0,
          spentAtm: 9999.0,
        ),
        AuthorizationDecision.approved,
      );
      expect(
        evaluate(
          config: settings(onlineLimit: 1.0, atmLimit: 1.0),
          transaction: txn(
            channel: CardTransactionChannel.magstripe,
            amount: 9999.0,
          ),
          spentOnline: 9999.0,
          spentAtm: 9999.0,
        ),
        AuthorizationDecision.approved,
      );
    });
  });

  group('geo-fencing', () {
    test('allows an explicitly permitted country', () {
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>['US', 'CA']),
          transaction: txn(merchantCountry: 'US'),
        ),
        AuthorizationDecision.approved,
      );
    });

    test('blocks a country that is not permitted', () {
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>['US', 'CA']),
          transaction: txn(merchantCountry: 'JP'),
        ),
        AuthorizationDecision.declinedGeoBlocked,
      );
    });

    test('matches country codes case-insensitively', () {
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>['us']),
          transaction: txn(merchantCountry: 'US'),
        ),
        AuthorizationDecision.approved,
      );
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>['Us']),
          transaction: txn(merchantCountry: 'uS'),
        ),
        AuthorizationDecision.approved,
      );
    });

    test('disabled geo-fencing allows any country', () {
      expect(
        evaluate(
          config: settings(geo: false, countries: const <String>['US']),
          transaction: txn(merchantCountry: 'JP'),
        ),
        AuthorizationDecision.approved,
      );
    });

    test('enabled geo-fencing with no allowed countries blocks all', () {
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>[]),
          transaction: txn(merchantCountry: 'US'),
        ),
        AuthorizationDecision.declinedGeoBlocked,
      );
    });

    test('geo block takes precedence over an exceeded limit', () {
      expect(
        evaluate(
          config: settings(
            geo: true,
            countries: const <String>['US'],
            onlineLimit: 1.0,
          ),
          transaction: txn(amount: 100.0, merchantCountry: 'JP'),
        ),
        AuthorizationDecision.declinedGeoBlocked,
      );
    });

    test('geo-fencing applies to the atm channel when enabled', () {
      expect(
        evaluate(
          config: settings(geo: true, countries: const <String>['US']),
          transaction: txn(
            channel: CardTransactionChannel.atm,
            merchantCountry: 'JP',
          ),
        ),
        AuthorizationDecision.declinedGeoBlocked,
      );
    });
  });

  group('non-positive amounts', () {
    test('zero amount is declined', () {
      expect(
        evaluate(transaction: txn(amount: 0.0)),
        AuthorizationDecision.declinedLimitExceeded,
      );
    });

    test('negative amount is declined', () {
      expect(
        evaluate(transaction: txn(amount: -25.0)),
        AuthorizationDecision.declinedLimitExceeded,
      );
    });

    test('zero amount on the atm channel is declined', () {
      expect(
        evaluate(
          transaction:
              txn(channel: CardTransactionChannel.atm, amount: 0.0),
        ),
        AuthorizationDecision.declinedLimitExceeded,
      );
    });

    test('zero amount on a disabled channel still reports the disabled channel',
        () {
      expect(
        evaluate(
          config: settings(contactless: false),
          transaction:
              txn(channel: CardTransactionChannel.contactless, amount: 0.0),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });
  });

  group('updateSettings', () {
    test('toggles a single channel immutably', () {
      final CardSecuritySettings base = settings();
      final CardSecuritySettings updated = service.updateSettings(
        base,
        isOnlinePaymentsEnabled: false,
      );
      expect(updated.isOnlinePaymentsEnabled, isFalse);
      expect(base.isOnlinePaymentsEnabled, isTrue);
      expect(
        evaluate(
          config: updated,
          transaction: txn(channel: CardTransactionChannel.online),
        ),
        AuthorizationDecision.declinedDueToChannelDisabled,
      );
    });

    test('updates limits and geo configuration', () {
      final CardSecuritySettings updated = service.updateSettings(
        settings(),
        dailyOnlineLimit: 250.0,
        dailyAtmAtmLimit: 125.0,
        isGeoFencingEnabled: true,
        allowedCountryCodes: const <String>['GB'],
      );
      expect(updated.dailyOnlineLimit, 250.0);
      expect(updated.dailyAtmAtmLimit, 125.0);
      expect(updated.isGeoFencingEnabled, isTrue);
      expect(updated.allowedCountryCodes, const <String>['GB']);
    });

    test('with no overrides returns an equal settings object', () {
      final CardSecuritySettings base = settings();
      expect(service.updateSettings(base), equals(base));
    });
  });
}
