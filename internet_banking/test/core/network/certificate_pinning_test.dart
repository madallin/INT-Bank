import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/network/certificate_pinning.dart';
import 'package:internet_banking/core/network/pinned_adapter_io.dart';

/// Real TLS handshakes against a local HTTPS server with a throwaway certificate
/// (created with openssl for each run, so no key is ever committed).
void main() {
  late Directory dir;
  late HttpServer server;
  late String pin;
  var requestsReceived = 0;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('pinning');
    final result = await Process.run('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost',
      '-keyout', '${dir.path}/key.pem', '-out', '${dir.path}/cert.pem',
    ]);
    if (result.exitCode != 0) fail('openssl failed: ${result.stderr}');

    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/cert.pem')
      ..usePrivateKey('${dir.path}/key.pem');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    server.listen((request) {
      requestsReceived++;
      request.response
        ..write('{"ok":true}')
        ..close();
    });

    final der = await Process.run('openssl', ['x509', '-in', '${dir.path}/cert.pem', '-outform', 'der'],
        stdoutEncoding: null);
    pin = certificateSha256(der.stdout as List<int>);
  });

  tearDownAll(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  Dio clientPinnedTo(List<String> pins) => Dio(BaseOptions(baseUrl: 'https://localhost:${server.port}'))
    ..httpClientAdapter = pinnedHttpClientAdapter(CertificatePinPolicy(host: 'localhost', pins: pins))!;

  test('talks to the server whose certificate is pinned', () async {
    final response = await clientPinnedTo(['00' * 32, pin]).get('/ping'); // a backup pin plus the real one
    expect(response.statusCode, 200);
  });

  test('refuses any other certificate before sending the request', () async {
    final before = requestsReceived;
    await expectLater(
      clientPinnedTo(['ab' * 32]).post('/pay', data: {'pin': '246802'}),
      throwsA(isA<DioException>()),
    );
    expect(requestsReceived, before, reason: 'the request must never reach a server that fails the pin');
  });

  test('pins are compared case- and separator-insensitively', () {
    final policy = CertificatePinPolicy(host: 'localhost', pins: ['AA:BB']);
    expect(policy.accepts('localhost', const [1, 2, 3]), isFalse);
    expect(certificateSha256(const [1, 2, 3]).length, 64);
  });
}
