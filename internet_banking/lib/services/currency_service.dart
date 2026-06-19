// lib/services/currency_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, X509Certificate;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// Singleton service that fetches and caches exchange rates from the server.
/// The server in turn caches them in Redis (TTL 1h), so calling this multiple
/// times within the same hour is instant and does NOT hit the Frankfurter API.
class CurrencyService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final CurrencyService _instance = CurrencyService._();
  static CurrencyService get instance => _instance;
  CurrencyService._();

  // ── State ──────────────────────────────────────────────────────────────
  Map<String, double>? _rates;            // e.g. { "EUR": 0.201, "USD": 0.216 }
  double _commissionPercent = 1.5;
  String _base = 'RON';
  String _lastCached = '';
  String _date = '';

  bool get hasRates => _rates != null;
  Map<String, double>? get rates => _rates;
  double get commissionPercent => _commissionPercent;
  String get base => _base;
  String get lastCached => _lastCached;
  String get date => _date;

  // ── HTTP client (skip SSL verification for dev) ────────────────────────
  http.Client _createHttpClient() {
    final ioc = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  // ── Fetch from server ──────────────────────────────────────────────────
  /// Fetches the latest rates from the server. The server caches in Redis,
  /// so this is safe to call frequently — it will only hit Frankfurter once
  /// per hour at most.
  Future<void> fetchRates() async {
    try {
      final client = _createHttpClient();
      final response = await client.get(
        Uri.parse('https://$serverUrl/currency/api/v1/exchange-rates'),
        headers: {'Accept': 'application/json'},
      );
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        _base = data['base'] as String? ?? 'RON';
        _date = data['date'] as String? ?? '';
        _lastCached = data['last_cached'] as String? ?? '';
        _commissionPercent = (data['commissionPercent'] as num?)?.toDouble() ?? 1.5;

        final rawRates = data['rates'] as Map<String, dynamic>?;
        if (rawRates != null) {
          _rates = rawRates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      }
    } catch (e) {
      // Silent fail — the UI will show "no rates" fallback
      debugPrint('CurrencyService: Failed to fetch rates — $e');
    }
  }

  // ── Conversion helpers (all calculations local) ────────────────────────

  /// Get the exchange rate from [from] to [to].
  /// Returns `null` if rates aren't loaded or the pair can't be calculated.
  double? getRate(String from, String to) {
    if (_rates == null) return null;
    if (from == to) return 1.0;

    // We have rates as: 1 RON = X foreign_currency
    // So: 1 EUR = (1 / rate[EUR]) RON  → for RON → EUR, use rate[EUR] directly
    // For EUR → USD: we need to go through RON
    if (from == _base) {
      // 1 RON = X foreign
      return _rates![to];
    } else if (to == _base) {
      // 1 foreign = 1 / rate[foreign] RON
      final rate = _rates![from];
      return rate != null ? 1.0 / rate : null;
    } else {
      // Cross-rate: 1 EUR → need USD = rate[USD] / rate[EUR]
      final rateFrom = _rates![from];
      final rateTo = _rates![to];
      if (rateFrom == null || rateTo == null) return null;
      return rateTo / rateFrom;
    }
  }

  /// Convert [amount] from [from] currency to [to], applying commission.
  /// Returns `null` if rates aren't loaded.
  double? convertWithCommission(double amount, String from, String to) {
    final rate = getRate(from, to);
    if (rate == null) return null;

    // Original rate (without commission)
    // For display we need the original rate separately
    return amount * rate * (1 - _commissionPercent / 100);
  }

  /// Get the original rate (without commission).
  double? getOriginalRate(String from, String to) {
    return getRate(from, to);
  }

  /// Get the effective rate (after commission).
  double? getEffectiveRate(String from, String to) {
    final rate = getRate(from, to);
    if (rate == null) return null;
    return rate * (1 - _commissionPercent / 100);
  }

  /// Calculate the commission amount for a conversion.
  double? getCommissionAmount(double amount, String from, String to) {
    final rate = getRate(from, to);
    if (rate == null) return null;
    return amount * rate * (_commissionPercent / 100);
  }
}
