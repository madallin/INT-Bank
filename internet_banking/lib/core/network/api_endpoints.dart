import '../../config/app_config.dart';

class ApiEndpoints
{
  static String get baseUrl => 'https://${AppConfig.serverUrl}';

  static String login = '$baseUrl/login';

  static String user(int userId) => '$baseUrl/users/$userId';
  static String userAccounts(int userId) => '$baseUrl/users/$userId/accounts';
  static String userAccount(int userId, int accountId) =>
      '$baseUrl/users/$userId/accounts/$accountId';
  static String accountTransactions(int userId, int accountId) =>
      '$baseUrl/users/$userId/accounts/$accountId/transactions';
  static String userCards(int userId) => '$baseUrl/users/$userId/cards';
  static String userCard(int userId, int cardId) =>
      '$baseUrl/users/$userId/cards/$cardId';
  static String cardTransactions(int userId, int cardId) =>
      '$baseUrl/users/$userId/cards/$cardId/transactions';

  static String exchangeRates = '$baseUrl/currency/api/v1/exchange-rates';
  static String convertCurrency = '$baseUrl/currency/api/v1/convert';

  static String authRefresh = '$baseUrl/auth-session/refresh';
  static String authLogin = '$baseUrl/auth-session/login';
  static String authLogout = '$baseUrl/auth-session/logout';

  static String register = '$baseUrl/register';
  static String approveUser(int userId) => '$baseUrl/users/$userId/approve';
  static String acceptTos(int userId) => '$baseUrl/users/$userId/accept-tos';
  static String hasTos(int userId) => '$baseUrl/users/$userId/has-tos';
  static String hasApproved(int userId) =>
      '$baseUrl/users/$userId/has-approved';
  static String submitDocuments(int userId) =>
      '$baseUrl/users/$userId/submit-documents';
  static String getIp() => '$baseUrl/ip';

  static String getClientToken = '$baseUrl/auth/get-client-token';
  static String refreshClientToken = '$baseUrl/auth/refresh-client-token';

  static String twoFactorRequest = '$baseUrl/2fa/request';
  static String twoFactorVerify = '$baseUrl/2fa/verify';
  static String hasPin(int userId) => '$baseUrl/users/$userId/has-pin';
  static String setPin(int userId) => '$baseUrl/users/$userId/set-pin';
  static String verifyPin(int userId) => '$baseUrl/users/$userId/verify-pin';

  static String transfer(int userId) => '$baseUrl/users/$userId/transfer';
  static String expressStatus = '$baseUrl/express_status';
}
