import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';

final DioClient _client = DioClient();

Future<int?> fetchUserProfile(int userId) async
{
  try
  {
    final response = await _client.get('/users/$userId');
    if(response.statusCode == 200)
    {
      final data = response.data as Map<String, dynamic>;
      return data['id'] as int?;
    }
    return null;
  }
  catch(_)
  {
    return null;
  }
}

Future<List<dynamic>?> fetchUserAccounts(int userId) async
{
  try
  {
    final response = await _client.get('/users/$userId/accounts');
    if(response.statusCode == 200)
    {
      final data = response.data as Map<String, dynamic>;
      return data['accounts'] as List<dynamic>;
    }
    return null;
  }
  catch(_)
  {
    return null;
  }
}

Future<List<dynamic>?> fetchUserCards(int userId, {String? clientToken}) async
{
  try
  {
    final response = await _client.get(
      '/users/$userId/cards',
      options: clientToken != null
          ? Options(headers: {'Authorization': 'Bearer $clientToken'})
          : null,
    );
    if(response.statusCode == 200)
    {
      final data = response.data as Map<String, dynamic>;
      return data['cards'] as List<dynamic>;
    }
    return null;
  }
  catch(_)
  {
    return null;
  }
}

Future<Map<String, dynamic>?> fetchUserData(int userId) async
{
  try
  {
    final response = await _client.get('/users/$userId');
    if(response.statusCode == 200)
    {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }
  catch(_)
  {
    return null;
  }
}
