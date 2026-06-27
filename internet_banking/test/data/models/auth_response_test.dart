import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/data/models/auth_response.dart';

void main() {
  group('AuthResponse', () {
    test('fromJson creates instance with correct values', () {
      final json = {
        'accessToken': 'test_access_token',
        'refreshToken': 'test_refresh_token',
        'userId': 42,
      };

      final response = AuthResponse.fromJson(json);

      expect(response.accessToken, 'test_access_token');
      expect(response.refreshToken, 'test_refresh_token');
      expect(response.userId, 42);
    });

    test('toJson returns correct map', () {
      final response = AuthResponse(
        accessToken: 'token123',
        refreshToken: 'refresh123',
        userId: 7,
      );

      final json = response.toJson();

      expect(json['accessToken'], 'token123');
      expect(json['refreshToken'], 'refresh123');
      expect(json['userId'], 7);
    });

    test('fromJson handles missing userId', () {
      final json = {
        'accessToken': 'token',
        'refreshToken': 'refresh',
      };

      final response = AuthResponse.fromJson(json);

      expect(response.accessToken, 'token');
      expect(response.refreshToken, 'refresh');
      expect(response.userId, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = AuthResponse(
        accessToken: 'old_token',
        refreshToken: 'old_refresh',
        userId: 1,
      );

      final modified = original.copyWith(accessToken: 'new_token');

      expect(modified.accessToken, 'new_token');
      expect(modified.refreshToken, 'old_refresh');
      expect(modified.userId, 1);
      expect(original.accessToken, 'old_token');
    });
  });
}
