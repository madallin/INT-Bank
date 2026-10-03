/// Romanian display formatting shared by every screen.
///
/// Numbers use `.` for thousands and `,` for decimals (`1.234,56`), dates use
/// `dd.MM.yyyy`. Keep all user-visible money/date strings going through here so
/// screens stay consistent.
library;

const String maskedFigure = '••••';

/// `1234.5` -> `1.234,50`. With [showSign], positive values get a `+`.
String formatAmount(num value, {int decimals = 2, bool showSign = false})
{
  final fixed = value.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final integer = dot == -1 ? fixed : fixed.substring(0, dot);
  final fraction = dot == -1 ? '' : fixed.substring(dot + 1);

  final grouped = StringBuffer();
  for(int i = 0; i < integer.length; i++)
  {
    if(i > 0 && (integer.length - i) % 3 == 0) grouped.write('.');
    grouped.write(integer[i]);
  }

  final isZero = double.parse(fixed) == 0;
  final sign = value < 0 && !isZero ? '-' : (showSign && value > 0 && !isZero ? '+' : '');
  return fraction.isEmpty ? '$sign$grouped' : '$sign$grouped,$fraction';
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

/// `dd.MM.yyyy`
String formatDate(DateTime date)
{
  final d = date.toLocal();
  return '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

/// `dd.MM.yyyy, HH:mm`
String formatDateTime(DateTime date)
{
  final d = date.toLocal();
  return '${formatDate(d)}, ${_two(d.hour)}:${_two(d.minute)}';
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
