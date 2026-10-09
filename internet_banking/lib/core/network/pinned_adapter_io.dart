import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'certificate_pinning.dart';

/// HTTP transport that only talks to a server presenting a pinned certificate.
///
/// No root CA is trusted, so every certificate reaches [HttpClient.badCertificateCallback]
/// during the TLS handshake; it is accepted only if it matches a pin. A man-in-the-middle
/// (even with a CA installed on the device) fails the handshake before any request
/// data, such as a PIN, is sent.
HttpClientAdapter? pinnedHttpClientAdapter(CertificatePinPolicy policy) =>
    IOHttpClientAdapter(createHttpClient: () => pinnedHttpClient(policy));

/// A dart:io client with the same pinning, for connections Dio does not make (WebSocket).
HttpClient pinnedHttpClient(CertificatePinPolicy policy)
{
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
  client.badCertificateCallback = (cert, host, port) => policy.accepts(host, cert.der);
  return client;
}
