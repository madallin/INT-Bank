import '../../core/network/dio_client.dart';

/// One of the customer's current accounts, as `GET /users/{id}/accounts` returns it.
class BankAccount
{
  const BankAccount({required this.id, required this.iban, required this.currency, required this.balance});

  final int id;
  final String iban;
  final String currency;
  final double balance;

  factory BankAccount.fromJson(Map<String, dynamic> json)
  {
    final sold = json['sold'];
    return BankAccount(
      id: (json['id'] as num).toInt(),
      iban: (json['iban'] ?? json['IBAN'] ?? '').toString(),
      currency: (json['moneda'] ?? 'RON').toString(),
      balance: sold is num ? sold.toDouble() : double.tryParse('$sold') ?? 0,
    );
  }

  /// The customer's current accounts, RON first, then by currency.
  static Future<List<BankAccount>> fetchAll(int userId) async
  {
    final response = await DioClient().get('/users/$userId/accounts');
    final data = response.data as Map<String, dynamic>;
    final accounts = [
      for(final json in (data['accounts'] as List? ?? const []))
        BankAccount.fromJson(Map<String, dynamic>.from(json as Map)),
    ];
    accounts.sort((a, b) => a.currency == b.currency
        ? a.id.compareTo(b.id)
        : a.currency == 'RON' ? -1 : b.currency == 'RON' ? 1 : a.currency.compareTo(b.currency));
    return accounts;
  }

  /// Fresh balance for one account.
  static Future<BankAccount> fetch(int userId, int accountId) async
  {
    final response = await DioClient().get('/users/$userId/accounts/$accountId');
    final data = response.data as Map<String, dynamic>;
    return BankAccount.fromJson(Map<String, dynamic>.from(data['account'] as Map));
  }
}
