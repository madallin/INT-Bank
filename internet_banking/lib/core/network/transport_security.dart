import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'certificate_pinning.dart';
import 'pinned_adapter_io.dart' show pinnedHttpClient;

/// How this build secures its connections to the bank.
enum TransportSecurity
{
  /// Only the pinned server certificate is accepted (CERT_SHA256_PINS).
  pinned,

  /// Ordinary certificate checks; allowed in debug builds only.
  systemTrust,

  /// A release build without pins: nothing is sent anywhere (fails closed).
  misconfigured,
}

/// One place that decides how every connection (API, notification stream, approval
/// socket) is secured, so a release build can never quietly run unpinned.
abstract final class TransportPolicy
{
  /// Release builds must pin. Tests switch this to check the release behaviour.
  @visibleForTesting
  static bool requirePins = kReleaseMode;

  static TransportSecurity get mode
  {
    if(AppConfig.certificatePins.isNotEmpty) return TransportSecurity.pinned;
    return requirePins ? TransportSecurity.misconfigured : TransportSecurity.systemTrust;
  }

  static CertificatePinPolicy pinPolicy(String host) =>
      CertificatePinPolicy(host: host, pins: AppConfig.certificatePins);

  /// A dart:io client for connections Dio does not make (notification stream, WebSocket).
  static HttpClient httpClient(String host) => switch(mode)
  {
    TransportSecurity.pinned => pinnedHttpClient(pinPolicy(host)),
    TransportSecurity.systemTrust => HttpClient(),
    // Trusts no certificate at all, so no handshake completes.
    TransportSecurity.misconfigured => HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..badCertificateCallback = (_, _, _) => false,
  };
}

/// Transport for a misconfigured release build: every request fails before anything is
/// sent, with the same error type as a rejected certificate.
class RefusingHttpClientAdapter implements HttpClientAdapter
{
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture)
  {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badCertificate,
      error: 'Certificate pins are not configured for this release build.',
    );
  }

  @override
  void close({bool force = false}) {}
}
