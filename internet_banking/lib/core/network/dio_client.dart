import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../../data/models/auth_response.dart';

class _PendingRequest
{
  _PendingRequest(this.options, this.handler);

  final RequestOptions options;
  final ErrorInterceptorHandler handler;
}

class DioClient
{
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';

  late final Dio _dio;
  late final Dio _refreshDio;

  bool _isRefreshing = false;
  final _pendingRequests = <_PendingRequest>[];

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

    _refreshDio = Dio(
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
          if(error.response?.statusCode != 401)
          {
            handler.next(error);
            return;
          }

          if(error.requestOptions.path.contains('/auth-session/refresh'))
          {
            handler.next(error);
            return;
          }

          if(_isRefreshing)
          {
            _pendingRequests.add(_PendingRequest(error.requestOptions, handler));
            return;
          }

          _isRefreshing = true;

          try
          {
            final refreshToken = await _storage.read(key: _refreshTokenKey);
            if(refreshToken == null || refreshToken.isEmpty)
            {
              await _clearSession();
              handler.next(error);
              return;
            }

            final refreshResponse = await _refreshDio.post(
              '/auth-session/refresh',
              data: {'refreshToken': refreshToken},
            );

            if(refreshResponse.statusCode == 200)
            {
              final data = refreshResponse.data as Map<String, dynamic>;
              final refreshResult = TokenRefreshResponse.fromJson(data);

              await _storage.write(key: _accessTokenKey, value: refreshResult.accessToken);
              await _storage.write(key: _refreshTokenKey, value: refreshResult.refreshToken);

              if(refreshResult.userId != null)
              {
                await _storage.write(key: 'userId', value: refreshResult.userId.toString());
              }

              error.requestOptions.headers['Authorization'] = 'Bearer ${refreshResult.accessToken}';

              for(final pending in _pendingRequests)
              {
                pending.options.headers['Authorization'] = 'Bearer ${refreshResult.accessToken}';
                try
                {
                  final retry = await _dio.fetch(pending.options);
                  pending.handler.resolve(retry);
                }
                catch(e)
                {
                  pending.handler.reject(error);
                }
              }
              _pendingRequests.clear();

              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          }
          catch(_)
          {
          }

          await _clearSession();

          for(final pending in _pendingRequests)
          {
            pending.handler.reject(error);
          }
          _pendingRequests.clear();

          handler.next(error);
        },
      ),
    );
  }

  Future<void> _clearSession() async
  {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: 'userId');
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
