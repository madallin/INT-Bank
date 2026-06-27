import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';

class DioClient
{
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'accessToken';

  late final Dio _dio;

  DioClient._internal()
  {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://$serverUrl',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async
        {
          final token = await _storage.read(key: _accessTokenKey);
          if(token != null && token.isNotEmpty)
          {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async
        {
          if(error.response?.statusCode == 401)
          {
            final refreshToken = await _storage.read(key: 'refreshToken');
            if(refreshToken != null && refreshToken.isNotEmpty)
            {
              try
              {
                final refreshResponse = await _dio.post(
                  '/auth-session/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if(refreshResponse.statusCode == 200)
                {
                  final newAccessToken = refreshResponse.data['accessToken'] as String?;
                  if(newAccessToken != null)
                  {
                    await _storage.write(key: _accessTokenKey, value: newAccessToken);
                    error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                    final retryResponse = await _dio.fetch(error.requestOptions);
                    return handler.resolve(retryResponse);
                  }
                }
              }
              catch(_)
              {
                // refresh failed — let the error propagate
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.delete<T>(path, queryParameters: queryParameters, options: options);
}

