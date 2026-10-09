import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:internet_banking/core/network/dio_client.dart';

/// A canned reply with an explicit HTTP status.
class FakeResponse
{
  const FakeResponse(this.status, this.body);

  final int status;
  final Object body;
}

/// Replies served in turn for one route; the last one repeats.
class FakeSequence
{
  const FakeSequence(this.replies);

  final List<Object> replies;
}

/// Serves canned JSON for the app's HTTP calls in widget tests.
///
/// Routes are matched on `METHOD path` (e.g. `GET /users/1/cards`); anything
/// unmatched gets a 404 so screens exercise their error paths. A route value
/// is a JSON body (200), a [FakeResponse], or a [FakeSequence] of those.
/// Bodies mirror the real API's shapes (lists are wrapped in an object).
class FakeApi implements HttpClientAdapter
{
  FakeApi(this.routes);

  final Map<String, Object> routes;
  final List<String> calls = [];

  /// Decoded JSON bodies sent with each request, in order.
  final List<Object?> sentBodies = [];

  /// `Authorization` header of each request, in order (null when absent).
  final List<String?> sentAuth = [];
  final Map<String, int> _served = {};

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
    sentBodies.add(options.data);
    sentAuth.add(options.headers['Authorization']?.toString());
    var route = routes[key];
    if(route is FakeSequence)
    {
      final index = _served.update(key, (n) => n + 1, ifAbsent: () => 0);
      route = route.replies[index < route.replies.length ? index : route.replies.length - 1];
    }
    final status = route == null ? 404 : route is FakeResponse ? route.status : 200;
    final body = route is FakeResponse ? route.body : route;
    return ResponseBody.fromString(
      jsonEncode(body ?? {'error': 'Not found in FakeApi: $key'}),
      status,
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
      'GET /users/$userId': {
        'id': userId,
        'nume': 'POPESCU',
        'prenume': 'ION',
        'email': 'ion.popescu@example.com',
        'nrTelefon': '+40712345678',
        'dataNasterii': '1990-04-12',
        'judet': 'Cluj',
        'localitate': 'Cluj-Napoca',
        'adresa': 'Str. Memorandumului 28',
        'contAprobat': true,
        'termeniAcceptati': true,
        'hasPin': true,
      },
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
          {'id': 1, 'amount': 1250, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Chirie octombrie', 'date': '2026-10-01T09:30:00', 'status': 'COMPLETED', 'category': 'UTILITATI'},
          {'id': 2, 'amount': 7430.5, 'currency': 'RON', 'type': 'CREDIT', 'reason': 'Salariu', 'date': '2026-09-28T08:00:00', 'status': 'COMPLETED', 'category': 'INCOMING'},
          {'id': 3, 'amount': 89.99, 'currency': 'RON', 'type': 'DEBIT', 'reason': 'Abonament internet', 'date': '2026-09-25T12:10:00', 'status': 'COMPLETED', 'category': 'UTILITATI'},
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
      'GET /users/$userId/accounts': {
        'accounts': [
          {'id': 101, 'iban': 'RO49INTB0001RON0000000001', 'moneda': 'RON', 'sold': 12345.67},
          {'id': 102, 'iban': 'RO49INTB0001EUR3F9A01BC', 'moneda': 'EUR', 'sold': 840.5},
        ],
      },
      'GET /users/$userId/vaults': {
        'vaults': [
          {'id': 31, 'name': 'Vacanță', 'balance': 1200.0, 'targetAmount': 3000.0, 'currency': 'RON', 'targetDate': '2027-06-01', 'lockType': 'FLEXIBLE', 'lockedToday': false},
          {'id': 32, 'name': 'Avans casă', 'balance': 5000.0, 'targetAmount': 20000.0, 'currency': 'RON', 'targetDate': '2027-12-31', 'lockType': 'LOCKED', 'lockedToday': true},
        ],
      },
      'GET /users/$userId/scheduled-transfers': {
        'scheduledTransfers': [
          {'id': 5, 'beneficiaryName': 'ANA IONESCU', 'toIban': 'RO96INTBRON0000000000002', 'amount': 210.0, 'currency': 'RON', 'frequency': 'MONTHLY', 'nextRunDate': '2026-11-01', 'reason': 'Chirie', 'status': 'ACTIVE'},
          {'id': 6, 'beneficiaryName': 'ION POPESCU', 'toIban': 'RO26INTBRON0000000000001', 'amount': 90.0, 'currency': 'RON', 'frequency': 'WEEKLY', 'nextRunDate': '2026-10-12', 'reason': 'Abonament', 'status': 'PAUSED', 'lastError': 'Limita zilnica depasita'},
          {'id': 7, 'beneficiaryName': 'VECHI', 'toIban': 'RO26INTBRON0000000000001', 'amount': 10.0, 'currency': 'RON', 'frequency': 'ONCE', 'nextRunDate': '2026-09-01', 'reason': 'Anulat', 'status': 'CANCELLED'},
        ],
      },
      'GET /users/$userId/beneficiaries': {
        'beneficiaries': [
          {'name': 'ANA IONESCU', 'iban': 'RO96INTBRON0000000000002', 'bankName': 'INTBank'},
        ],
      },
      'GET /users/$userId/accounts/101/analytics': {
        'currency': 'RON',
        'totalSpent': 2140.49,
        'topCategory': 'Facturi & Utilități',
        'totalTransactions': 9,
        'categories': [
          {'categoryName': 'Facturi & Utilități', 'categoryKey': 'UTILITATI', 'amount': 1250.0, 'percentage': 58.4, 'transactionCount': 1},
          {'categoryName': 'Alimente & Supermarket', 'categoryKey': 'ALIMENTE', 'amount': 610.5, 'percentage': 28.5, 'transactionCount': 5},
          {'categoryName': 'Divertisment & Servicii', 'categoryKey': 'DIVERTISMENT', 'amount': 279.99, 'percentage': 13.1, 'transactionCount': 3},
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
      // Same shape as CurrencyController: units of each currency per 1 RON, no fee.
      'GET /currency/api/v1/exchange-rates': {
        'base': 'RON',
        'rates': {'RON': 1.0, 'EUR': 0.20116, 'USD': 0.21968, 'GBP': 0.16997},
        'commission_percent': 0,
      },
    });
