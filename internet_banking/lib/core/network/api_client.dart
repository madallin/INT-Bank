import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

IOClient _createIOClient()
{
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

class ApiClient
{
  final IOClient _client;
  String? _accessToken;
  String? _refreshToken;

  ApiClient._(this._client);
  factory ApiClient()
  {
    return ApiClient._(_createIOClient());
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  void setTokens({String? accessToken, String? refreshToken})
  {
    if(accessToken != null) _accessToken = accessToken;
    if(refreshToken != null) _refreshToken = refreshToken;
  }

  Map<String, String> _headers({Map<String, String>? extra})
  {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if(_accessToken != null)
    {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if(extra != null) headers.addAll(extra);
    return headers;
  }

  Future<http.Response> get(String url, {Map<String, String>? headers}) =>
      _client.get(Uri.parse(url), headers: _headers(extra: headers));

  Future<http.Response> post(String url,
          {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _client.post(Uri.parse(url),
          headers: _headers(extra: headers),
          body: body != null ? jsonEncode(body) : null);

  Future<http.Response> put(String url,
          {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _client.put(Uri.parse(url),
          headers: _headers(extra: headers),
          body: body != null ? jsonEncode(body) : null);

  Future<http.Response> patch(String url,
          {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _client.patch(Uri.parse(url),
          headers: _headers(extra: headers),
          body: body != null ? jsonEncode(body) : null);

  Future<http.Response> delete(String url,
          {Map<String, String>? headers}) =>
      _client.delete(Uri.parse(url), headers: _headers(extra: headers));

  void close() => _client.close();
}
