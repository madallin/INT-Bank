import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:internet_banking/core/network/dio_client.dart';

/// Serves canned JSON for the app's HTTP calls in widget tests.
///
/// Routes are matched on `METHOD path` (e.g. `GET /users/1/cards`); anything
/// unmatched gets a 404 so screens exercise their error paths.
class FakeApi implements HttpClientAdapter
{
  FakeApi(this.routes);

  final Map<String, Object> routes;
  final List<String> calls = [];

  /// Installs this fake as the transport for every [DioClient] request.
  void install() => DioClient.debugUseAdapter(this);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async
  {
    final key = '${options.method} ${options.uri.path}';
    calls.add(key);
    final body = routes[key];
    return ResponseBody.fromString(
      jsonEncode(body ?? {'error': 'Not found in FakeApi: $key'}),
      body == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A signed-in customer with two cards (RON and EUR) and a few transactions.
FakeApi demoCustomerApi({int userId = 1}) => FakeApi({
      'POST /auth/get-client-token': {'client_token': 'test-token', 'refresh_token': 'test-refresh'},
      'GET /users/$userId/cards': {
        'cards': [
          {
            'id': 11,
            'accountId': 101,
            'cardNumber': '4111111111114821',
            'cardHolder': 'Ion Popescu',
            'expiryDate': '09/29',
            'cvv': '123',
            'cardType': 'VISA',
          },
          {
            'id': 12,
            'accountId': 102,
            'cardNumber': '4111111111119934',
            'cardHolder': 'Ion Popescu',
            'expiryDate': '03/28',
            'cvv': '456',
            'cardType': 'VISA',
          },
        ],
      },
      'GET /users/$userId/accounts/101': {
        'account': {'id': 101, 'iban': 'RO49INTB0001RON0000000001', 'moneda': 'RON', 'sold': 12345.67},
      },
      'GET /users/$userId/accounts/102': {
        'account': {'id': 102, 'iban': 'RO49INTB0001EUR3F9A01BC', 'moneda': 'EUR', 'sold': 840.5},
      },
      'GET /users/$userId/accounts/101/transactions': {
        'transactions': [
          {'id': 1, 'amount': 1250, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Chirie octombrie', 'date': '2026-10-01T09:30:00', 'status': 'COMPLETED'},
          {'id': 2, 'amount': 7430.5, 'currency': 'RON', 'type': 'CREDIT', 'reason': 'Salariu', 'date': '2026-09-28T08:00:00', 'status': 'COMPLETED'},
          {'id': 3, 'amount': 89.99, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Abonament internet', 'date': '2026-09-25T12:10:00', 'status': 'COMPLETED'},
        ],
      },
      'GET /users/$userId/accounts/102/transactions': {'transactions': []},
      'GET /users/$userId/notifications': {
        'unreadCount': 2,
        'notifications': [
          {'id': 1, 'type': 'TRANSFER_RECEIVED', 'title': 'Ai primit 7.430,50 RON', 'message': 'Salariu de la ANGAJATOR SRL', 'read': false},
          {'id': 2, 'type': 'SECURITY_ALERT', 'title': 'Autentificare nouă', 'message': 'Contul a fost accesat de pe un dispozitiv nou.', 'read': false},
          {'id': 3, 'type': 'SYSTEM', 'title': 'Cont nou în EUR deschis', 'message': 'Noul tău cont curent în EUR este gata de utilizare.', 'read': true},
        ],
      },
      'GET /users/$userId/accounts': [
        {'id': 101, 'iban': 'RO49INTB0001RON0000000001', 'moneda': 'RON', 'sold': 12345.67},
        {'id': 102, 'iban': 'RO49INTB0001EUR3F9A01BC', 'moneda': 'EUR', 'sold': 840.5},
      ],
      'GET /users/$userId/scheduled-transfers': [
        {'id': 5, 'beneficiaryName': 'ENGIE ROMANIA', 'toIban': 'RO49AAAA1B31007593840000', 'amount': 210.0, 'frequency': 'MONTHLY', 'nextRunDate': '2026-11-01', 'reason': 'Factură gaz'},
      ],
      'GET /users/$userId/beneficiaries': {
        'beneficiaries': [
          {'name': 'ION POPESCU', 'iban': 'RO49AAAA1B31007593840000', 'bankName': 'Banca Transilvania'},
        ],
      },
      'GET /users/$userId/accounts/101/analytics': {
        'currency': 'RON',
        'totalSpent': 2140.49,
        'topCategory': 'Locuință',
        'totalTransactions': 9,
        'categories': [
          {'categoryName': 'Locuință', 'categoryKey': 'HOUSING', 'amount': 1250.0, 'percentage': 58.4, 'transactionCount': 1},
          {'categoryName': 'Cumpărături', 'categoryKey': 'SHOPPING', 'amount': 610.5, 'percentage': 28.5, 'transactionCount': 5},
          {'categoryName': 'Abonamente', 'categoryKey': 'SUBSCRIPTIONS', 'amount': 279.99, 'percentage': 13.1, 'transactionCount': 3},
        ],
      },
      'GET /users/$userId/accounts/101/statement': {
        'currency': 'RON',
        'openingBalance': 6255.16,
        'totalInflows': 7430.5,
        'totalOutflows': 1339.99,
        'closingBalance': 12345.67,
        'transactions': [
          {'type': 'CREDIT', 'amount': 7430.5, 'partyName': 'ANGAJATOR SRL', 'description': 'Salariu', 'date': '28.09.2026'},
          {'type': 'DEBIT', 'amount': 1250.0, 'partyName': 'ION POPESCU', 'description': 'Chirie octombrie', 'date': '01.10.2026'},
        ],
      },
      'GET /currency/api/v1/exchange-rates': {
        'rates': {
          'EUR': {'RON': 4.9712},
          'USD': {'RON': 4.5521},
          'GBP': {'RON': 5.8834},
        },
        'commission_percent': 1.0,
      },
    });
