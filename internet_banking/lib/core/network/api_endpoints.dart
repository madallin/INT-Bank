// lib/core/network/api_endpoints.dart
// Centralized API endpoint definitions

import '../../config/app_config.dart';

class ApiEndpoints {
  static String get baseUrl => 'https://$serverUrl';

  // Auth
  static const String getClientToken = '/auth/get-client-token';
  static const String refreshClientToken = '/auth/refresh-client-token';

  // Login & Registration
  static const String login = '/login';
  static const String register = '/register';

  // 2FA
  static const String twoFactorRequest = '/2fa/request';
  static const String twoFactorVerify = '/2fa/verify';

  // Users
  static String user(int userId) => '/users/$userId';
  static String setPin(int userId) => '/users/$userId/set-pin';
  static String verifyPin(int userId) => '/users/$userId/verify-pin';
  static String hasPin(int userId) => '/users/$userId/has-pin';
  static String hasTos(int userId) => '/users/$userId/has-tos';
  static String acceptTos(int userId) => '/users/$userId/accept-tos';
  static String hasApproved(int userId) => '/users/$userId/has-approved/';
  static String createAccountAndCard(int userId) =>
      '/users/$userId/create-account-and-card';

  // Cards & Accounts
  static String cards(int userId) => '/users/$userId/cards';
  static String cardDetails(int userId, int cardId) =>
      '/users/$userId/cards/$cardId/details';
  static String account(int userId, int accountId) =>
      '/users/$userId/accounts/$accountId';
  static String transactions(int userId, int accountId) =>
      '/users/$userId/accounts/$accountId/transactions';

  // Transfers
  static String transfer(int userId) => '/users/$userId/transfer';

  // Exchange
  static const String exchangeRates = '/exchange/rates';

  // Google Places
  static String placesAutocomplete(String text, String locality) =>
      '/places/autocomplete?text=${Uri.encodeComponent(text)}&locality=${Uri.encodeComponent(locality)}';
  static String placeDetails(String placeId) =>
      '/places/details?place_id=${Uri.encodeComponent(placeId)}';

  // Health
  static const String health = '/health';
  static const String status = '/express_status';

  // WebSocket
  static String get wsBaseUrl => 'wss://$serverUrl';
}
