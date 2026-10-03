/// One row of `GET /users/{id}/accounts/{accountId}/transactions`.
///
/// The backend sends `amount`, `currency`, `type` (`DEBIT`/`CREDIT`), `reason`
/// and `date`. Older builds of the API used Romanian keys (`suma`, `moneda`,
/// `motiv`, `dataTransfer`, `type: received`), which are still accepted so the
/// list never breaks on a stale server.
class TransactionEntry
{
  const TransactionEntry({
    required this.amount,
    required this.isIncoming,
    required this.title,
    this.currency,
    this.date,
    this.fromIban,
    this.toIban,
  });

  /// Always positive; direction is in [isIncoming].
  final double amount;
  final bool isIncoming;
  final String title;
  final String? currency;
  final DateTime? date;
  final String? fromIban;
  final String? toIban;

  /// Amount with its direction applied (negative for money out).
  double get signedAmount => isIncoming ? amount : -amount;

  factory TransactionEntry.fromJson(Map<String, dynamic> json)
  {
    final rawAmount = json['amount'] ?? json['suma'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final type = json['type']?.toString().toUpperCase();
    final isIncoming = type == 'CREDIT' || type == 'RECEIVED';

    String? text(List<String> keys)
    {
      for(final key in keys)
      {
        final value = json[key]?.toString().trim();
        if(value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final rawDate = text(['date', 'dataTransfer']);
    return TransactionEntry(
      amount: amount.abs(),
      isIncoming: isIncoming,
      title: text(['beneficiary', 'reason', 'description', 'motiv']) ?? 'Transfer bancar',
      currency: text(['currency', 'moneda']),
      date: rawDate == null ? null : DateTime.tryParse(rawDate),
      fromIban: text(['fromIban']),
      toIban: text(['toIban', 'iban']),
    );
  }

  /// Text that the history search matches against.
  String get searchText => [title, fromIban, toIban]
      .whereType<String>()
      .join(' ')
      .toLowerCase();
}
