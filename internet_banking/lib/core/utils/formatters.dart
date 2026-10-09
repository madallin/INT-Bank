/// Display formatting shared by every screen, in the app's active language.
///
/// Romanian: `1.234,56` and `dd.MM.yyyy`. English: `1,234.56` and `10 Oct 2026`.
/// Keep all user-visible money/date strings going through here so screens stay
/// consistent, and so typed amounts (see `AmountInputFormatter`) use the same
/// separators as displayed ones.
library;

import '../../l10n/l10n.dart';

/// Thousands and decimal separators of the active language.
typedef NumberSeparators = ({String group, String decimal});

bool get _english => AppL10n.current.localeName.startsWith('en');

NumberSeparators get numberSeparators => _english ? (group: ',', decimal: '.') : (group: '.', decimal: ',');

const String maskedFigure = '••••';

/// `1234.5` -> `1.234,50` (Romanian) or `1,234.50` (English). With [showSign],
/// positive values get a `+`.
String formatAmount(num value, {int decimals = 2, bool showSign = false})
{
  final sep = numberSeparators;
  final fixed = value.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final integer = dot == -1 ? fixed : fixed.substring(0, dot);
  final fraction = dot == -1 ? '' : fixed.substring(dot + 1);

  final grouped = StringBuffer();
  for(int i = 0; i < integer.length; i++)
  {
    if(i > 0 && (integer.length - i) % 3 == 0) grouped.write(sep.group);
    grouped.write(integer[i]);
  }

  final isZero = double.parse(fixed) == 0;
  final sign = value < 0 && !isZero ? '-' : (showSign && value > 0 && !isZero ? '+' : '');
  return fraction.isEmpty ? '$sign$grouped' : '$sign$grouped${sep.decimal}$fraction';
}

/// `formatMoney(-12.5, 'RON')` -> `-12,50 RON`.
String formatMoney(num value, String currency, {int decimals = 2, bool showSign = false})
{
  return '${formatAmount(value, decimals: decimals, showSign: showSign)} $currency';
}

/// Placeholder shown instead of an amount while privacy mode is on.
String maskedMoney(String currency) => '$maskedFigure $currency';

/// Exchange rates keep four decimals: `4,9712`.
String formatRate(num rate) => formatAmount(rate, decimals: 4);

/// `12.34` -> `12,3%`.
String formatPercent(num value, {int decimals = 1})
{
  return '${formatAmount(value, decimals: decimals)}%';
}

String _two(int n) => n.toString().padLeft(2, '0');

const _englishMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `dd.MM.yyyy` in Romanian; `10 Oct 2026` in English (no day/month order to misread).
String formatDate(DateTime date)
{
  final d = date.toLocal();
  if(_english) return '${d.day} ${_englishMonths[d.month - 1]} ${d.year}';
  return '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

/// The date with `, HH:mm`.
String formatDateTime(DateTime date)
{
  final d = date.toLocal();
  return '${formatDate(d)}, ${_two(d.hour)}:${_two(d.minute)}';
}

/// `HH:mm`, local time.
String formatTime(DateTime date)
{
  final d = date.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// Formats a server timestamp; returns the raw text when it cannot be parsed.
String formatIsoDate(String? iso, {bool withTime = false})
{
  if(iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  if(parsed == null) return iso;
  return withTime ? formatDateTime(parsed) : formatDate(parsed);
}

/// `yyyy-MM-dd`, the date format the backend expects in request bodies.
String formatApiDate(DateTime date)
{
  return '${date.year}-${_two(date.month)}-${_two(date.day)}';
}

/// Groups characters in blocks of four, as printed on cards and IBANs.
String groupInFours(String raw)
{
  final clean = raw.replaceAll(RegExp(r'\s'), '');
  final buffer = StringBuffer();
  for(int i = 0; i < clean.length; i++)
  {
    if(i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(clean[i]);
  }
  return buffer.toString();
}

/// `ro49intb...` -> `RO49 INTB ...`
String formatIban(String iban) => groupInFours(iban.toUpperCase());
