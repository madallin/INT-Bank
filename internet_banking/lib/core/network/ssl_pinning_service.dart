import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Immutable pinning configuration for a single host.
@immutable
class SslPinConfig {
  const SslPinConfig({
    required this.host,
    required this.allowedSha256Pins,
    required this.enforcePinning,
    required this.pinExpirationDate,
  });

  final String host;
  final List<String> allowedSha256Pins;
  final bool enforcePinning;
  final DateTime pinExpirationDate;
}

enum SslVerificationStatus {
  validPinMatch,
  pinMismatchRejected,
  expiredPins,
  bypassAttemptDetected,
  hostNotConfigured,
}

@immutable
class SslVerificationResult {
  const SslVerificationResult({
    required this.host,
    required this.status,
    this.certificateFingerprint,
    this.errorMessage,
  });

  final String host;
  final SslVerificationStatus status;
  final String? certificateFingerprint;
  final String? errorMessage;
}

/// Immutable security alert emitted on rejected or suspicious pin events.
@immutable
class SslSecurityAlert {
  const SslSecurityAlert({
    required this.host,
    required this.candidateFingerprint,
    required this.status,
    required this.timestamp,
  });

  final String host;
  final String candidateFingerprint;
  final SslVerificationStatus status;
  final DateTime timestamp;
}

/// Injectable sink invoked whenever a security-relevant pin event occurs.
typedef SslSecurityAlertSink = void Function(SslSecurityAlert alert);

final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

/// SHA-256 certificate/public-key pin verifier with primary and backup pins.
class SslPinningService {
  SslPinningService({SslSecurityAlertSink? alertSink}) : _alertSink = alertSink;

  final SslSecurityAlertSink? _alertSink;
  final Map<String, SslPinConfig> _configs = <String, SslPinConfig>{};

  void registerHostPin(SslPinConfig config) {
    _configs[_normalizeHost(config.host)] = config;
  }

  SslVerificationResult verifyCertificateFingerprint({
    required String host,
    required String candidateFingerprint,
    required DateTime currentTime,
  }) {
    final config = _configs[_normalizeHost(host)];
    if (config == null) {
      return SslVerificationResult(
        host: host,
        status: SslVerificationStatus.hostNotConfigured,
        certificateFingerprint: candidateFingerprint,
        errorMessage: 'No pin configuration registered for host',
      );
    }

    final String normalizedCandidate = _normalizeFingerprint(candidateFingerprint);
    if (normalizedCandidate.isEmpty) {
      _emitAlert(
        host: host,
        candidateFingerprint: candidateFingerprint,
        status: SslVerificationStatus.bypassAttemptDetected,
        timestamp: currentTime,
      );
      return SslVerificationResult(
        host: host,
        status: SslVerificationStatus.bypassAttemptDetected,
        certificateFingerprint: candidateFingerprint,
        errorMessage: 'Empty or blank certificate fingerprint presented',
      );
    }

    if (!config.enforcePinning) {
      _emitAlert(
        host: host,
        candidateFingerprint: candidateFingerprint,
        status: SslVerificationStatus.bypassAttemptDetected,
        timestamp: currentTime,
      );
      return SslVerificationResult(
        host: host,
        status: SslVerificationStatus.bypassAttemptDetected,
        certificateFingerprint: candidateFingerprint,
        errorMessage: 'Pinning enforcement disabled for host',
      );
    }

    if (currentTime.isAfter(config.pinExpirationDate)) {
      _emitAlert(
        host: host,
        candidateFingerprint: candidateFingerprint,
        status: SslVerificationStatus.expiredPins,
        timestamp: currentTime,
      );
      return SslVerificationResult(
        host: host,
        status: SslVerificationStatus.expiredPins,
        certificateFingerprint: candidateFingerprint,
        errorMessage: 'Pinned SHA-256 certificates expired for host',
      );
    }

    final Set<String> allowedPins = config.allowedSha256Pins
        .map(_normalizeFingerprint)
        .where((String pin) => pin.isNotEmpty)
        .toSet();

    if (allowedPins.contains(normalizedCandidate)) {
      return SslVerificationResult(
        host: host,
        status: SslVerificationStatus.validPinMatch,
        certificateFingerprint: candidateFingerprint,
      );
    }

    _emitAlert(
      host: host,
      candidateFingerprint: candidateFingerprint,
      status: SslVerificationStatus.pinMismatchRejected,
      timestamp: currentTime,
    );
    return SslVerificationResult(
      host: host,
      status: SslVerificationStatus.pinMismatchRejected,
      certificateFingerprint: candidateFingerprint,
      errorMessage: 'Certificate fingerprint does not match any allowed pin',
    );
  }

  bool isConnectionPermitted({
    required String host,
    required String candidateFingerprint,
    required DateTime currentTime,
  }) =>
      verifyCertificateFingerprint(
        host: host,
        candidateFingerprint: candidateFingerprint,
        currentTime: currentTime,
      ).status ==
      SslVerificationStatus.validPinMatch;

  void _emitAlert({
    required String host,
    required String candidateFingerprint,
    required SslVerificationStatus status,
    required DateTime timestamp,
  }) {
    final SslSecurityAlertSink? sink = _alertSink;
    if (sink == null) {
      return;
    }
    sink(
      SslSecurityAlert(
        host: host,
        candidateFingerprint: candidateFingerprint,
        status: status,
        timestamp: timestamp,
      ),
    );
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();

  /// Normalizes hex and base64 SHA-256 pins to a canonical lowercase hex form so
  /// equivalent fingerprints compare deterministically across encodings.
  static String _normalizeFingerprint(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final String compact = trimmed.replaceAll(':', '').replaceAll(' ', '');
    if (_isHex(compact)) {
      return compact.toLowerCase();
    }

    try {
      final List<int> decoded = base64.decode(base64.normalize(trimmed));
      if (decoded.isNotEmpty) {
        return _toHex(decoded);
      }
    } on FormatException {
      // Not valid base64; fall back to literal case-insensitive comparison.
    }

    return trimmed.toLowerCase();
  }

  static bool _isHex(String value) {
    if (value.isEmpty || value.length.isOdd) {
      return false;
    }
    return _hexPattern.hasMatch(value);
  }

  static String _toHex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
