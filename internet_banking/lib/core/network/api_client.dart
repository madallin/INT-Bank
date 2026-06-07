// lib/core/network/api_client.dart
// HTTP client factory with SSL bypass for development

import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show HttpClient, X509Certificate;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../config/app_config.dart';

/// Creates an HTTP client that bypasses SSL certificate validation
/// (intended for development with self-signed certs).
IOClient createHttpClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

/// Checks whether a response body is valid JSON.
bool isJson(String str) {
  try {
    jsonDecode(str);
    return true;
  } catch (_) {
    return false;
  }
}

/// Attempts to refresh the client token.
Future<String?> refreshClientToken({
  required String deviceId,
  required String refreshToken,
}) async {
  final client = createHttpClient();
  try {
    final response = await client.post(
      Uri.parse('https://$serverUrl/auth/refresh-client-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'refreshToken': refreshToken,
      }),
    );
    if (response.statusCode == 200 && isJson(response.body)) {
      final data = jsonDecode(response.body);
      return data['client_token'] as String?;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Obtains a fresh client token from the server.
Future<Map<String, dynamic>?> getClientToken({
  required String deviceId,
}) async {
  final client = createHttpClient();
  try {
    final response = await client.post(
      Uri.parse('https://$serverUrl/auth/get-client-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId}),
    );
    if (response.statusCode == 200 && isJson(response.body)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } finally {
    client.close();
  }
}

/// Performs a GET request with automatic token refresh on 401.
Future<http.Response> fetchWithRefresh(
  Uri uri,
  String? clientToken,
  String refreshToken,
  String deviceId,
) async {
  final client = createHttpClient();

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
        body: jsonEncode({
          'deviceId': deviceId,
          'refreshToken': refreshToken,
        }),
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
