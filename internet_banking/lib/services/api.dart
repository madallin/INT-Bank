import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

http.Client _createHttpClient()
{
  final ioc = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(ioc);
}

Future<Map<String, dynamic>?> fetchUserProfile(int userId) async
{
  final client = _createHttpClient();
  try
  {
    final response = await client.get(
      Uri.parse('https://$serverUrl/users/$userId'),
    );
    if(response.statusCode == 200)
    {
      return jsonDecode(response.body);
    }
    return null;
  }
  catch(e)
  {
    return null;
  }
  finally
  {
    client.close();
  }
}

Future<List<dynamic>?> fetchUserAccounts(int userId) async
{
  final client = _createHttpClient();
  try
  {
    final response = await client.get(
      Uri.parse('https://$serverUrl/users/$userId/accounts'),
    );
    if(response.statusCode == 200)
    {
      final data = jsonDecode(response.body);
      return data['accounts'] as List<dynamic>;
    }
    return null;
  }
  catch(e)
  {
    return null;
  }
  finally
  {
    client.close();
  }
}

Future<List<dynamic>?> fetchUserCards(int userId, {String? clientToken}) async
{
  final client = _createHttpClient();
  try
  {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if(clientToken != null)
    {
      headers['Authorization'] = 'Bearer $clientToken';
    }
    final response = await client.get(
      Uri.parse('https://$serverUrl/users/$userId/cards'),
      headers: headers,
    );
    if(response.statusCode == 200)
    {
      final data = jsonDecode(response.body);
      return data['cards'] as List<dynamic>;
    }
    return null;
  }
  catch(e)
  {
    return null;
  }
  finally
  {
    client.close();
  }
}

Future<Map<String, dynamic>?> fetchUserData(int userId) async
{
  final client = _createHttpClient();
  try
  {
    final response = await client.get(
      Uri.parse('https://$serverUrl/users/$userId'),
    );
    if(response.statusCode == 200)
    {
      return jsonDecode(response.body);
    }
    return null;
  }
  catch(e)
  {
    return null;
  }
  finally
  {
    client.close();
  }
}
