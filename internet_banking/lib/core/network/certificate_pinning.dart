import 'package:crypto/crypto.dart';

import 'ssl_pinning_service.dart';

/// SHA-256 of a DER-encoded certificate, as lowercase hex (the pin format).
String certificateSha256(List<int> der) => sha256.convert(der).toString();

/// Decides whether a server certificate may complete the TLS handshake for [host].
///
/// Pins are SHA-256 hashes of the server's leaf certificate. Keep the next certificate's
/// pin in the list before rotating, so an update never locks clients out.
class CertificatePinPolicy
{
  CertificatePinPolicy({
    required this.host,
    required List<String> pins,
    DateTime? pinsExpireAt,
    SslSecurityAlertSink? onRejected,
  }) : _service = SslPinningService(alertSink: onRejected)
          ..registerHostPin(SslPinConfig(
            host: host,
            allowedSha256Pins: pins,
            enforcePinning: true,
            pinExpirationDate: pinsExpireAt ?? DateTime(2100),
          ));

  final String host;
  final SslPinningService _service;

  bool accepts(String certificateHost, List<int> der, {DateTime? now}) =>
      _service.verifyCertificateFingerprint(
        host: certificateHost,
        candidateFingerprint: certificateSha256(der),
        currentTime: now ?? DateTime.now(),
      ).status ==
      SslVerificationStatus.validPinMatch;
}
