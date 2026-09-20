import 'package:flutter/foundation.dart';

/// Transaction channel a card authorization is attempted over.
enum CardTransactionChannel { online, atm, contactless, magstripe }

/// Deterministic outcome of evaluating a transaction against card controls.
enum AuthorizationDecision {
  approved,
  declinedDueToChannelDisabled,
  declinedLimitExceeded,
  declinedGeoBlocked,
}

/// Immutable configuration of per-channel card security controls.
@immutable
class CardSecuritySettings {
  final bool isOnlinePaymentsEnabled;
  final bool isAtmWithdrawalsEnabled;
  final bool isContactlessEnabled;
  final bool isMagstripeEnabled;
  final bool isGeoFencingEnabled;
  final List<String> allowedCountryCodes;
  final double dailyAtmAtmLimit;
  final double dailyOnlineLimit;

  const CardSecuritySettings({
    this.isOnlinePaymentsEnabled = true,
    this.isAtmWithdrawalsEnabled = true,
    this.isContactlessEnabled = true,
    this.isMagstripeEnabled = true,
    this.isGeoFencingEnabled = false,
    this.allowedCountryCodes = const <String>[],
    this.dailyAtmAtmLimit = 1000.0,
    this.dailyOnlineLimit = 5000.0,
  });

  /// Sensible out-of-the-box configuration with every channel enabled.
  const CardSecuritySettings.defaults()
      : isOnlinePaymentsEnabled = true,
        isAtmWithdrawalsEnabled = true,
        isContactlessEnabled = true,
        isMagstripeEnabled = true,
        isGeoFencingEnabled = false,
        allowedCountryCodes = const <String>[],
        dailyAtmAtmLimit = 1000.0,
        dailyOnlineLimit = 5000.0;

  /// Returns a copy with the supplied fields replaced.
  CardSecuritySettings copyWith({
    bool? isOnlinePaymentsEnabled,
    bool? isAtmWithdrawalsEnabled,
    bool? isContactlessEnabled,
    bool? isMagstripeEnabled,
    bool? isGeoFencingEnabled,
    List<String>? allowedCountryCodes,
    double? dailyAtmAtmLimit,
    double? dailyOnlineLimit,
  }) {
    return CardSecuritySettings(
      isOnlinePaymentsEnabled:
          isOnlinePaymentsEnabled ?? this.isOnlinePaymentsEnabled,
      isAtmWithdrawalsEnabled:
          isAtmWithdrawalsEnabled ?? this.isAtmWithdrawalsEnabled,
      isContactlessEnabled:
          isContactlessEnabled ?? this.isContactlessEnabled,
      isMagstripeEnabled: isMagstripeEnabled ?? this.isMagstripeEnabled,
      isGeoFencingEnabled:
          isGeoFencingEnabled ?? this.isGeoFencingEnabled,
      allowedCountryCodes: allowedCountryCodes ?? this.allowedCountryCodes,
      dailyAtmAtmLimit: dailyAtmAtmLimit ?? this.dailyAtmAtmLimit,
      dailyOnlineLimit: dailyOnlineLimit ?? this.dailyOnlineLimit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CardSecuritySettings &&
        other.isOnlinePaymentsEnabled == isOnlinePaymentsEnabled &&
        other.isAtmWithdrawalsEnabled == isAtmWithdrawalsEnabled &&
        other.isContactlessEnabled == isContactlessEnabled &&
        other.isMagstripeEnabled == isMagstripeEnabled &&
        other.isGeoFencingEnabled == isGeoFencingEnabled &&
        listEquals(other.allowedCountryCodes, allowedCountryCodes) &&
        other.dailyAtmAtmLimit == dailyAtmAtmLimit &&
        other.dailyOnlineLimit == dailyOnlineLimit;
  }

  @override
  int get hashCode => Object.hash(
        isOnlinePaymentsEnabled,
        isAtmWithdrawalsEnabled,
        isContactlessEnabled,
        isMagstripeEnabled,
        isGeoFencingEnabled,
        Object.hashAll(allowedCountryCodes),
        dailyAtmAtmLimit,
        dailyOnlineLimit,
      );

  @override
  String toString() =>
      'CardSecuritySettings(online: $isOnlinePaymentsEnabled, '
      'atm: $isAtmWithdrawalsEnabled, '
      'contactless: $isContactlessEnabled, '
      'magstripe: $isMagstripeEnabled, '
      'geoFencing: $isGeoFencingEnabled, '
      'allowedCountryCodes: $allowedCountryCodes, '
      'dailyAtmAtmLimit: $dailyAtmAtmLimit, '
      'dailyOnlineLimit: $dailyOnlineLimit)';
}

/// Immutable description of a transaction under evaluation.
@immutable
class CardTransaction {
  final CardTransactionChannel channel;
  final double amount;
  final String merchantCountry;
  final DateTime timestamp;

  const CardTransaction({
    required this.channel,
    required this.amount,
    required this.merchantCountry,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CardTransaction &&
        other.channel == channel &&
        other.amount == amount &&
        other.merchantCountry == merchantCountry &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      Object.hash(channel, amount, merchantCountry, timestamp);

  @override
  String toString() =>
      'CardTransaction(channel: $channel, amount: $amount, '
      'merchantCountry: $merchantCountry, timestamp: $timestamp)';
}

/// Determines authorization decisions for card transactions.
///
/// Evaluation is fully deterministic: the same settings, transaction and
/// spend snapshots always produce the same decision.
class CardSecurityControlsService {
  const CardSecurityControlsService();

  /// Evaluates a transaction against per-channel controls, geo-fencing and
  /// daily spend limits.
  ///
  /// Order of evaluation is channel enabled, then geo-fencing, then limits.
  AuthorizationDecision evaluateTransaction({
    required CardSecuritySettings settings,
    required CardTransaction transaction,
    required double spentOnlineToday,
    required double spentAtmToday,
  }) {
    if (!_isChannelEnabled(settings, transaction.channel)) {
      return AuthorizationDecision.declinedDueToChannelDisabled;
    }

    if (_isGeoBlocked(settings, transaction)) {
      return AuthorizationDecision.declinedGeoBlocked;
    }

    if (_isLimitExceeded(
      settings: settings,
      transaction: transaction,
      spentOnlineToday: spentOnlineToday,
      spentAtmToday: spentAtmToday,
    )) {
      return AuthorizationDecision.declinedLimitExceeded;
    }

    return AuthorizationDecision.approved;
  }

  /// Returns a copy of [settings] with any supplied controls replaced.
  CardSecuritySettings updateSettings(
    CardSecuritySettings settings, {
    bool? isOnlinePaymentsEnabled,
    bool? isAtmWithdrawalsEnabled,
    bool? isContactlessEnabled,
    bool? isMagstripeEnabled,
    bool? isGeoFencingEnabled,
    List<String>? allowedCountryCodes,
    double? dailyAtmAtmLimit,
    double? dailyOnlineLimit,
  }) {
    return settings.copyWith(
      isOnlinePaymentsEnabled: isOnlinePaymentsEnabled,
      isAtmWithdrawalsEnabled: isAtmWithdrawalsEnabled,
      isContactlessEnabled: isContactlessEnabled,
      isMagstripeEnabled: isMagstripeEnabled,
      isGeoFencingEnabled: isGeoFencingEnabled,
      allowedCountryCodes: allowedCountryCodes,
      dailyAtmAtmLimit: dailyAtmAtmLimit,
      dailyOnlineLimit: dailyOnlineLimit,
    );
  }

  bool _isChannelEnabled(
    CardSecuritySettings settings,
    CardTransactionChannel channel,
  ) {
    switch (channel) {
      case CardTransactionChannel.online:
        return settings.isOnlinePaymentsEnabled;
      case CardTransactionChannel.atm:
        return settings.isAtmWithdrawalsEnabled;
      case CardTransactionChannel.contactless:
        return settings.isContactlessEnabled;
      case CardTransactionChannel.magstripe:
        return settings.isMagstripeEnabled;
    }
  }

  bool _isGeoBlocked(
    CardSecuritySettings settings,
    CardTransaction transaction,
  ) {
    if (!settings.isGeoFencingEnabled) {
      return false;
    }
    final String country = transaction.merchantCountry.trim().toLowerCase();
    for (final String allowed in settings.allowedCountryCodes) {
      if (allowed.trim().toLowerCase() == country) {
        return false;
      }
    }
    return true;
  }

  bool _isLimitExceeded({
    required CardSecuritySettings settings,
    required CardTransaction transaction,
    required double spentOnlineToday,
    required double spentAtmToday,
  }) {
    if (transaction.amount <= 0) {
      return true;
    }
    switch (transaction.channel) {
      case CardTransactionChannel.online:
        return spentOnlineToday + transaction.amount >
            settings.dailyOnlineLimit;
      case CardTransactionChannel.atm:
        return spentAtmToday + transaction.amount > settings.dailyAtmAtmLimit;
      case CardTransactionChannel.contactless:
      case CardTransactionChannel.magstripe:
        return false;
    }
  }
}
