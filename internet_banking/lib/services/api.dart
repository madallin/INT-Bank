import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../config/app_config.dart';

IOClient _createIOClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

Future<http.Response> fetchWithRefresh(
    Uri uri, String? clientToken, String refreshToken, String deviceId) async {
  final client = _createIOClient();

  http.Response response = await client.get(uri, headers: {
    'Authorization': 'Bearer $clientToken',
    'Accept': 'application/json',
  });

  if (response.statusCode == 401) {
    final body = jsonDecode(response.body);
    if (body['code'] == 'TOKEN_EXPIRED') {
      final refreshRes = await client.post(
        Uri.parse('https://$serverUrl/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId, 'refreshToken': refreshToken}),
      );

      if (refreshRes.statusCode == 200) {
        final data = jsonDecode(refreshRes.body);
        final newToken = data['client_token'];

        clientToken = newToken;

        response = await client.get(uri, headers: {
          'Authorization': 'Bearer $clientToken',
          'Accept': 'application/json',
        });
      }
    }
  }

  client.close();
  return response;
}
