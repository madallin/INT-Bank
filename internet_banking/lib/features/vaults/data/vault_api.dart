import '../../../core/network/dio_client.dart';

/// A savings vault as the bank reports it. The money is held by the bank in the
/// vault's own savings account; every change goes through [VaultApi].
class Vault
{
  const Vault({
    required this.id,
    required this.name,
    required this.balance,
    required this.targetAmount,
    required this.currency,
    required this.isLocked,
    required this.lockedToday,
    this.targetDate,
  });

  final int id;
  final String name;
  final double balance;
  final double targetAmount;
  final String currency;
  final DateTime? targetDate;

  /// Created as "locked": withdrawals wait for [targetDate].
  final bool isLocked;

  /// Locked right now (before the target date).
  final bool lockedToday;

  double get progress => targetAmount <= 0 ? 0 : (balance / targetAmount).clamp(0.0, 1.0);
  bool get goalReached => balance >= targetAmount;

  factory Vault.fromJson(Map<String, dynamic> json) => Vault(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'RON',
        targetDate: DateTime.tryParse(json['targetDate']?.toString() ?? ''),
        isLocked: json['lockType'] == 'LOCKED',
        lockedToday: json['lockedToday'] == true,
      );
}

/// One of the customer's current accounts, a source or destination for vault money.
class VaultAccount
{
  const VaultAccount({required this.id, required this.iban, required this.currency, required this.balance});

  final int id;
  final String iban;
  final String currency;
  final double balance;

  factory VaultAccount.fromJson(Map<String, dynamic> json) => VaultAccount(
        id: (json['id'] as num).toInt(),
        iban: (json['iban'] ?? json['IBAN'] ?? '').toString(),
        currency: json['moneda']?.toString() ?? 'RON',
        balance: (json['sold'] as num?)?.toDouble() ?? 0,
      );
}

class VaultApi
{
  VaultApi(this.userId, {DioClient? client}) : _client = client ?? DioClient();

  final int userId;
  final DioClient _client;

  String get _base => '/users/$userId/vaults';

  Future<List<Vault>> list() async
  {
    final response = await _client.get(_base);
    final raw = response.data is Map ? (response.data as Map)['vaults'] : null;
    return raw is List ? raw.whereType<Map>().map((v) => Vault.fromJson(Map<String, dynamic>.from(v))).toList() : [];
  }

  /// The customer's current accounts (vault savings accounts are not listed).
  Future<List<VaultAccount>> accounts() async
  {
    final response = await _client.get('/users/$userId/accounts');
    final raw = response.data is Map ? (response.data as Map)['accounts'] : null;
    return raw is List
        ? raw.whereType<Map>().map((a) => VaultAccount.fromJson(Map<String, dynamic>.from(a))).toList()
        : [];
  }

  Future<Vault> create({
    required String name,
    required double targetAmount,
    required int sourceAccountId,
    required bool locked,
    DateTime? targetDate,
  }) async =>
      _vault(await _client.post(_base, data: {
        'name': name,
        'targetAmount': targetAmount,
        'sourceAccountId': sourceAccountId,
        'lockType': locked ? 'LOCKED' : 'FLEXIBLE',
        if (targetDate != null) 'targetDate': _isoDate(targetDate),
      }));

  Future<Vault> deposit(int vaultId, {required int accountId, required double amount}) async =>
      _vault(await _client.post('$_base/$vaultId/deposit', data: {'accountId': accountId, 'amount': amount}));

  Future<Vault> withdraw(int vaultId, {required int accountId, required double amount}) async =>
      _vault(await _client.post('$_base/$vaultId/withdraw', data: {'accountId': accountId, 'amount': amount}));

  /// Pays the remaining balance into [accountId] and closes the vault.
  Future<void> close(int vaultId, {required int accountId}) =>
      _client.post('$_base/$vaultId/close', data: {'accountId': accountId});

  static Vault _vault(dynamic response) =>
      Vault.fromJson(Map<String, dynamic>.from((response.data as Map)['vault'] as Map));

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
