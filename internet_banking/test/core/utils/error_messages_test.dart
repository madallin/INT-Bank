import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/error_messages.dart';

DioException dioError(DioExceptionType type, {int? status, Object? data}) {
  final options = RequestOptions(path: 'https://internal.example:8443/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
    message: 'SocketException: host internal.example refused',
  );
}

void main() {
  group('friendlyErrorMessage', () {
    test('never exposes raw exception text', () {
      final msg = friendlyErrorMessage(
          dioError(DioExceptionType.connectionError));
      expect(msg, isNot(contains('internal.example')));
      expect(msg, isNot(contains('SocketException')));
    });

    test('maps connection problems to a connectivity hint', () {
      expect(friendlyErrorMessage(dioError(DioExceptionType.connectionError)),
          contains('conexiunea la internet'));
      expect(friendlyErrorMessage(dioError(DioExceptionType.receiveTimeout)),
          contains('nu răspunde'));
    });

    test('prefers the server provided error message', () {
      final e = dioError(DioExceptionType.badResponse,
          status: 400, data: {'error': 'Fonduri insuficiente'});
      expect(friendlyErrorMessage(e), 'Fonduri insuficiente');
    });

    test('maps status codes when the server gives no message', () {
      expect(
          friendlyErrorMessage(
              dioError(DioExceptionType.badResponse, status: 401)),
          contains('Sesiunea a expirat'));
      expect(
          friendlyErrorMessage(
              dioError(DioExceptionType.badResponse, status: 503)),
          contains('temporar indisponibil'));
    });

    test('uses the fallback for unknown errors', () {
      expect(
          friendlyErrorMessage(StateError('boom'), fallback: 'Fallback'),
          'Fallback');
      expect(
          friendlyErrorMessage(
              dioError(DioExceptionType.badResponse, status: 418),
              fallback: 'Fallback'),
          'Fallback');
    });
  });
}
