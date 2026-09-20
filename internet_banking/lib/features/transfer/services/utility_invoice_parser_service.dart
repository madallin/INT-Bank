import 'package:flutter/foundation.dart';

enum UtilityProviderType { enel, eon, digi, orange, vodafone, unknown }

@immutable
class ParsedUtilityInvoice {
  final String providerName;
  final UtilityProviderType providerType;
  final String customerCode;
  final String invoiceNumber;
  final double amount;
  final DateTime dueDate;
  final String paymentIban;

  const ParsedUtilityInvoice({
    required this.providerName,
    required this.providerType,
    required this.customerCode,
    required this.invoiceNumber,
    required this.amount,
    required this.dueDate,
    required this.paymentIban,
  });

  ParsedUtilityInvoice copyWith({
    String? providerName,
    UtilityProviderType? providerType,
    String? customerCode,
    String? invoiceNumber,
    double? amount,
    DateTime? dueDate,
    String? paymentIban,
  }) {
    return ParsedUtilityInvoice(
      providerName: providerName ?? this.providerName,
      providerType: providerType ?? this.providerType,
      customerCode: customerCode ?? this.customerCode,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paymentIban: paymentIban ?? this.paymentIban,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'providerName': providerName,
      'providerType': providerType.name,
      'customerCode': customerCode,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paymentIban': paymentIban,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedUtilityInvoice &&
        other.providerName == providerName &&
        other.providerType == providerType &&
        other.customerCode == customerCode &&
        other.invoiceNumber == invoiceNumber &&
        other.amount == amount &&
        other.dueDate == dueDate &&
        other.paymentIban == paymentIban;
  }

  @override
  int get hashCode => Object.hash(
        providerName,
        providerType,
        customerCode,
        invoiceNumber,
        amount,
        dueDate,
        paymentIban,
      );

  @override
  String toString() {
    return 'ParsedUtilityInvoice(providerName: $providerName, '
        'providerType: $providerType, customerCode: $customerCode, '
        'invoiceNumber: $invoiceNumber, amount: $amount, dueDate: $dueDate, '
        'paymentIban: $paymentIban)';
  }
}

/// Parses Romanian utility bill barcodes and QR payloads.
///
/// Supported providers: Enel, E.ON, Digi, Orange and Vodafone.
///
/// Three textual conventions are recognized:
///  - Key/value records delimited by `;` or `,`, for example
///    `PROVIDER=ENEL;CLIENT=123;INVOICE=INV-1;AMOUNT=245.50;`
///    `DUEDATE=15.03.2026;IBAN=RO32ENEL1B31007593840000`.
///  - Pipe positional records with exactly six fields:
///    `PROVIDER|CUSTOMER|INVOICE|AMOUNT|DUEDATE|IBAN`.
///  - The "factura" 1D/QR numeric convention: exactly 36 digits followed by
///    a Romanian IBAN. The 36 digits are laid out as
///    `<provider:2><customer:10><invoice:10><amount:8><dueDate:6>`.
///    The amount field holds the value in bani with every digit shifted
///    forward by its zero based position modulo ten, which is reversed when
///    decoding.
///
/// Barcode symbol payloads are supported through [parseBarcode]:
///  - Code 39, as a `*...*` delimited character string.
///  - Code 128, as a comma or space separated list of integer symbol values
///    (0-106), including Code Set B and Code Set C digit pairs.
class UtilityInvoiceParserService {
  static const double maxAmount = 100000.0;
  static const int maxDueDateFutureDays = 1825;

  static final DateTime _minDueDate = DateTime.utc(2000, 1, 1);
  static final RegExp _facturaPattern =
      RegExp(r'^\d{36}RO\d{2}[A-Z0-9]{20}$');
  static final RegExp _code128Pattern =
      RegExp(r'^\d{1,3}(?:[,\s]+\d{1,3}){2,}$');
  static final RegExp _whitespacePattern = RegExp(r'\s+');
  static final RegExp _ibanCharactersPattern = RegExp(r'^[A-Z0-9]{24}$');

  static const String _code39Alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. \$/+%';

  static const Map<String, UtilityProviderType> _ibanPrefixProviders =
      <String, UtilityProviderType>{
    'ENEL': UtilityProviderType.enel,
    'EONB': UtilityProviderType.eon,
    'DIGI': UtilityProviderType.digi,
    'ORAN': UtilityProviderType.orange,
    'VODA': UtilityProviderType.vodafone,
  };

  static const Map<String, UtilityProviderType> _providerCodes =
      <String, UtilityProviderType>{
    '01': UtilityProviderType.enel,
    '02': UtilityProviderType.eon,
    '03': UtilityProviderType.digi,
    '04': UtilityProviderType.orange,
    '05': UtilityProviderType.vodafone,
  };

  static const Map<String, String> _code39Patterns = <String, String>{
    '0': 'nnnwwnwnn',
    '1': 'wnnwnnnnw',
    '2': 'nnwwnnnnw',
    '3': 'wnwwnnnnn',
    '4': 'nnnwwnnnw',
    '5': 'wnnwwnnnn',
    '6': 'nnwwwnnnn',
    '7': 'nnnwnnwnw',
    '8': 'wnnwnnwnn',
    '9': 'nnwwnnwnn',
    'A': 'wnnnnwnnw',
    'B': 'nnwnnwnnw',
    'C': 'wnwnnwnnn',
    'D': 'nnnnwwnnw',
    'E': 'wnnnwwnnn',
    'F': 'nnwnwwnnn',
    'G': 'nnnnnwwnw',
    'H': 'wnnnnwwnn',
    'I': 'nnwnnwwnn',
    'J': 'nnnnwwwnn',
    'K': 'wnnnnnnww',
    'L': 'nnwnnnnww',
    'M': 'wnwnnnnwn',
    'N': 'nnnnwnnww',
    'O': 'wnnnwnnwn',
    'P': 'nnwnwnnwn',
    'Q': 'nnnnnnwww',
    'R': 'wnnnnnwwn',
    'S': 'nnwnnnwwn',
    'T': 'nnnnwnwwn',
    'U': 'wwnnnnnnw',
    'V': 'nwwnnnnnw',
    'W': 'wwwnnnnnn',
    'X': 'nwnnwnnnw',
    'Y': 'wwnnwnnnn',
    'Z': 'nwwnwnnnn',
    '-': 'nwnnnnwnw',
    '.': 'wwnnnnwnn',
    ' ': 'nwwnnnwnn',
    '\$': 'nwnwnwnnn',
    '/': 'nwnwnnnwn',
    '+': 'nwnnnwnwn',
    '%': 'nnnwnwnwn',
    '*': 'nwnnwnwnn',
  };

  static final Map<String, String> _code39ByPattern = <String, String>{
    for (final MapEntry<String, String> entry in _code39Patterns.entries)
      entry.value: entry.key,
  };

  /// Deterministic default clock used for due date validation.
  final DateTime Function() now;

  UtilityInvoiceParserService({this.now = _defaultNow});

  static DateTime _defaultNow() => DateTime.utc(2026, 1, 1);

  static double _round2(double value) => (value * 100).round() / 100;

  /// Auto detects the payload convention and parses it.
  ParsedUtilityInvoice parse(String raw, {UtilityProviderType? providerHint}) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty utility invoice payload');
    }
    if (trimmed.startsWith('*') || _looksLikeCode128(trimmed)) {
      return parseBarcode(trimmed, providerHint: providerHint);
    }
    if (_looksLikeFactura(trimmed)) {
      return _parseFactura(trimmed, providerHint);
    }
    if (trimmed.contains('=')) {
      return _parseKeyValue(trimmed, providerHint);
    }
    if (trimmed.contains('|')) {
      return _parsePositional(trimmed, providerHint);
    }
    throw const FormatException('Unrecognized utility invoice format');
  }

  /// Parses a QR textual payload.
  ParsedUtilityInvoice parseQr(
    String raw, {
    UtilityProviderType? providerHint,
  }) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty utility invoice payload');
    }
    if (_looksLikeFactura(trimmed)) {
      return _parseFactura(trimmed, providerHint);
    }
    if (trimmed.contains('=')) {
      return _parseKeyValue(trimmed, providerHint);
    }
    if (trimmed.contains('|')) {
      return _parsePositional(trimmed, providerHint);
    }
    throw const FormatException('Unrecognized utility QR format');
  }

  /// Parses a 1D barcode payload, decoding Code 39 or Code 128 when needed.
  ParsedUtilityInvoice parseBarcode(
    String raw, {
    UtilityProviderType? providerHint,
  }) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty utility barcode payload');
    }
    if (trimmed.startsWith('*')) {
      final String decoded = decodeCode39(trimmed);
      return parseQr(decoded, providerHint: providerHint);
    }
    if (_looksLikeCode128(trimmed)) {
      final String decoded = decodeCode128(trimmed);
      return parseQr(decoded, providerHint: providerHint);
    }
    if (_looksLikeFactura(trimmed)) {
      return _parseFactura(trimmed, providerHint);
    }
    return parseQr(trimmed, providerHint: providerHint);
  }

  /// Detects the provider from free text keywords.
  UtilityProviderType detectProvider(String text) {
    final String upper = text.toUpperCase();
    if (upper.contains('VODAFONE')) return UtilityProviderType.vodafone;
    if (upper.contains('ORANGE')) return UtilityProviderType.orange;
    if (upper.contains('DIGI') || upper.contains('RCS')) {
      return UtilityProviderType.digi;
    }
    if (upper.contains('ENEL')) return UtilityProviderType.enel;
    if (upper.contains('E.ON') || upper.contains('EON')) {
      return UtilityProviderType.eon;
    }
    return UtilityProviderType.unknown;
  }

  /// Canonical display name for a provider type.
  String providerNameFor(UtilityProviderType type) {
    switch (type) {
      case UtilityProviderType.enel:
        return 'Enel';
      case UtilityProviderType.eon:
        return 'E.ON';
      case UtilityProviderType.digi:
        return 'Digi';
      case UtilityProviderType.orange:
        return 'Orange';
      case UtilityProviderType.vodafone:
        return 'Vodafone';
      case UtilityProviderType.unknown:
        return 'Unknown';
    }
  }

  /// Validates a Romanian IBAN using the ISO 7064 mod-97 check.
  bool isValidRomanianIban(String iban) {
    final String cleaned =
        iban.replaceAll(_whitespacePattern, '').toUpperCase();
    if (cleaned.length != 24) return false;
    if (!cleaned.startsWith('RO')) return false;
    if (!_ibanCharactersPattern.hasMatch(cleaned)) return false;
    return _mod97(cleaned) == 1;
  }

  /// Decodes a `*...*` delimited Code 39 character string.
  String decodeCode39(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.length < 2 ||
        !trimmed.startsWith('*') ||
        !trimmed.endsWith('*')) {
      throw const FormatException(
        'Code 39 payload must be delimited by asterisks',
      );
    }
    final String inner = trimmed.substring(1, trimmed.length - 1);
    if (inner.isEmpty) {
      throw const FormatException('Code 39 payload is empty');
    }
    final StringBuffer buffer = StringBuffer();
    for (final int rune in inner.runes) {
      final String character = String.fromCharCode(rune).toUpperCase();
      if (!_code39Alphabet.contains(character)) {
        throw FormatException('Invalid Code 39 character: $character');
      }
      buffer.write(character);
    }
    return buffer.toString();
  }

  /// Decodes Code 39 width patterns (`n` narrow, `w` wide).
  ///
  /// The input is the concatenation of nine element patterns, one per
  /// character, including the leading and trailing `*` delimiters.
  String decodeCode39Patterns(String patterns) {
    final String trimmed = patterns.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed.length % 9 != 0) {
      throw const FormatException(
        'Code 39 pattern length must be a non zero multiple of 9',
      );
    }
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i += 9) {
      final String chunk = trimmed.substring(i, i + 9);
      final String? character = _code39ByPattern[chunk];
      if (character == null) {
        throw FormatException('Unknown Code 39 pattern: $chunk');
      }
      buffer.write(character);
    }
    return buffer.toString();
  }

  /// Computes the Code 128 checksum for a start symbol plus data symbols.
  ///
  /// The start symbol contributes with weight one and each following data
  /// symbol contributes with its one based position. The result is the
  /// weighted sum modulo 103.
  int computeCode128Checksum(List<int> symbols) {
    if (symbols.isEmpty) {
      throw const FormatException('Code 128 symbol list is empty');
    }
    int sum = symbols[0];
    for (int i = 1; i < symbols.length; i++) {
      sum += symbols[i] * i;
    }
    return sum % 103;
  }

  /// Decodes a comma or space separated list of Code 128 symbol values.
  String decodeCode128(String encoded) {
    final String trimmed = encoded.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Code 128 payload is empty');
    }
    final List<String> tokens = trimmed.split(RegExp(r'[,\s]+'));
    final List<int> symbols = <int>[];
    for (final String token in tokens) {
      if (token.isEmpty) continue;
      final int? value = int.tryParse(token);
      if (value == null) {
        throw FormatException('Invalid Code 128 symbol: $token');
      }
      symbols.add(value);
    }
    return decodeCode128Symbols(symbols);
  }

  /// Decodes a Code 128 symbol sequence including checksum and stop.
  ///
  /// Symbol values must be in the range 0-106, start with 103, 104 or 105 and
  /// end with 106. Code Set B and Code Set C are supported, including
  /// switching between the two. Code Set A is rejected.
  String decodeCode128Symbols(List<int> symbols) {
    if (symbols.length < 3) {
      throw const FormatException('Code 128 payload is too short');
    }
    for (final int value in symbols) {
      if (value < 0 || value > 106) {
        throw FormatException('Code 128 symbol out of range: $value');
      }
    }
    if (symbols.last != 106) {
      throw const FormatException(
        'Code 128 payload must end with the STOP symbol 106',
      );
    }
    final int providedChecksum = symbols[symbols.length - 2];
    final List<int> body = symbols.sublist(0, symbols.length - 2);
    final int expectedChecksum = computeCode128Checksum(body);
    if (providedChecksum != expectedChecksum) {
      throw FormatException(
        'Code 128 checksum mismatch: expected $expectedChecksum, '
        'got $providedChecksum',
      );
    }
    final int start = body[0];
    if (start == 103) {
      throw const FormatException(
        'Code 128 Code Set A start is not supported',
      );
    }
    if (start != 104 && start != 105) {
      throw FormatException('Invalid Code 128 start symbol: $start');
    }

    int codeSet = start == 104 ? 66 : 67;
    final StringBuffer buffer = StringBuffer();
    for (int i = 1; i < body.length; i++) {
      final int value = body[i];
      if (codeSet == 66) {
        if (value <= 95) {
          buffer.writeCharCode(value + 32);
        } else if (value == 99) {
          codeSet = 67;
        } else if (value == 100) {
          continue;
        } else if (value == 101) {
          throw const FormatException(
            'Code 128 Code Set A is not supported',
          );
        } else {
          throw FormatException(
            'Unsupported Code 128 Code Set B symbol: $value',
          );
        }
      } else {
        if (value <= 99) {
          buffer.write(value.toString().padLeft(2, '0'));
        } else if (value == 100) {
          codeSet = 66;
        } else if (value == 101) {
          throw const FormatException(
            'Code 128 Code Set A is not supported',
          );
        } else {
          throw FormatException(
            'Unsupported Code 128 Code Set C symbol: $value',
          );
        }
      }
    }
    return buffer.toString();
  }

  bool _looksLikeCode128(String raw) {
    final String compact = raw.replaceAll(_whitespacePattern, ' ').trim();
    return _code128Pattern.hasMatch(compact);
  }

  bool _looksLikeFactura(String raw) {
    final String compact =
        raw.replaceAll(_whitespacePattern, '').toUpperCase();
    return _facturaPattern.hasMatch(compact);
  }

  ParsedUtilityInvoice _parseKeyValue(
    String raw,
    UtilityProviderType? providerHint,
  ) {
    final Map<String, String> values = <String, String>{};
    final String delimiter = raw.contains(';') ? ';' : ',';
    for (final String segment in raw.split(delimiter)) {
      final String entry = segment.trim();
      if (entry.isEmpty) continue;
      final int separator = entry.indexOf('=');
      if (separator <= 0) {
        throw FormatException('Malformed key=value segment: $entry');
      }
      final String key = entry.substring(0, separator).trim().toUpperCase();
      values[key] = entry.substring(separator + 1).trim();
    }

    String firstOf(List<String> keys) {
      for (final String key in keys) {
        final String? value = values[key];
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }

    return _buildInvoice(
      providerRaw: firstOf(<String>['PROVIDER', 'UTILITY', 'FURNIZOR']),
      customerCode: firstOf(<String>[
        'CLIENT',
        'CUSTOMER',
        'CUSTOMERCODE',
        'CODCLIENT',
        'CLIENTCODE',
        'CLIENTID',
      ]),
      invoiceNumber: firstOf(<String>[
        'INVOICE',
        'INVOICENUMBER',
        'INVOICENO',
        'FACTURA',
        'NUMARFACTURA',
        'NRFACTURA',
        'INVOICEID',
      ]),
      amountRaw: firstOf(<String>['AMOUNT', 'TOTAL', 'SUMA', 'VALOARE']),
      dueRaw: firstOf(<String>[
        'DUEDATE',
        'DUE',
        'DATASCADENTA',
        'SCADENTA',
        'EXPIRY',
      ]),
      ibanRaw: firstOf(<String>['IBAN', 'CONT', 'CONTIBAN', 'ACCOUNT']),
      providerHint: providerHint,
    );
  }

  ParsedUtilityInvoice _parsePositional(
    String raw,
    UtilityProviderType? providerHint,
  ) {
    final List<String> parts =
        raw.split('|').map((String part) => part.trim()).toList();
    if (parts.length != 6) {
      throw FormatException(
        'Pipe positional payload must contain exactly 6 fields, '
        'found ${parts.length}',
      );
    }
    return _buildInvoice(
      providerRaw: parts[0],
      customerCode: parts[1],
      invoiceNumber: parts[2],
      amountRaw: parts[3],
      dueRaw: parts[4],
      ibanRaw: parts[5],
      providerHint: providerHint,
    );
  }

  ParsedUtilityInvoice _parseFactura(
    String raw,
    UtilityProviderType? providerHint,
  ) {
    final String compact =
        raw.replaceAll(_whitespacePattern, '').toUpperCase();
    if (!_facturaPattern.hasMatch(compact)) {
      throw const FormatException('Malformed factura barcode');
    }
    final String digits = compact.substring(0, 36);
    final String iban = compact.substring(36);

    final String providerCode = digits.substring(0, 2);
    final String customer = _stripLeadingZeros(digits.substring(2, 12));
    final String invoice = _stripLeadingZeros(digits.substring(12, 22));
    final double amount = _decodeObfuscatedAmount(digits.substring(22, 30));
    final DateTime dueDate = _parseDate(digits.substring(30, 36));
    _validateDueDate(dueDate);

    if (!isValidRomanianIban(iban)) {
      throw FormatException('Invalid Romanian IBAN: $iban');
    }

    UtilityProviderType type = _providerCodes[providerCode] ??
        UtilityProviderType.unknown;
    if (type == UtilityProviderType.unknown) {
      type = _providerFromIban(iban);
    }
    if (type == UtilityProviderType.unknown && providerHint != null) {
      type = providerHint;
    }

    return ParsedUtilityInvoice(
      providerName: providerNameFor(type),
      providerType: type,
      customerCode: customer,
      invoiceNumber: invoice,
      amount: amount,
      dueDate: dueDate,
      paymentIban: iban,
    );
  }

  ParsedUtilityInvoice _buildInvoice({
    required String providerRaw,
    required String customerCode,
    required String invoiceNumber,
    required String amountRaw,
    required String dueRaw,
    required String ibanRaw,
    required UtilityProviderType? providerHint,
  }) {
    final String customer = customerCode.trim();
    final String invoice = invoiceNumber.trim();
    if (customer.isEmpty) {
      throw const FormatException('Customer code is missing');
    }
    if (invoice.isEmpty) {
      throw const FormatException('Invoice number is missing');
    }

    final double amount = _parseAmount(amountRaw);
    final DateTime dueDate = _parseDate(dueRaw);
    _validateDueDate(dueDate);

    final String iban =
        ibanRaw.replaceAll(_whitespacePattern, '').toUpperCase();
    if (!isValidRomanianIban(iban)) {
      throw FormatException('Invalid Romanian IBAN: $ibanRaw');
    }

    UtilityProviderType type = detectProvider(providerRaw);
    if (type == UtilityProviderType.unknown) {
      type = _providerFromIban(iban);
    }
    if (type == UtilityProviderType.unknown && providerHint != null) {
      type = providerHint;
    }

    final String providerName;
    if (type != UtilityProviderType.unknown) {
      providerName = providerNameFor(type);
    } else {
      final String raw = providerRaw.trim();
      providerName = raw.isEmpty ? 'Unknown' : raw;
    }

    return ParsedUtilityInvoice(
      providerName: providerName,
      providerType: type,
      customerCode: customer,
      invoiceNumber: invoice,
      amount: amount,
      dueDate: dueDate,
      paymentIban: iban,
    );
  }

  UtilityProviderType _providerFromIban(String iban) {
    final String cleaned =
        iban.replaceAll(_whitespacePattern, '').toUpperCase();
    if (cleaned.length < 8) return UtilityProviderType.unknown;
    final String bankCode = cleaned.substring(4, 8);
    return _ibanPrefixProviders[bankCode] ?? UtilityProviderType.unknown;
  }

  double _parseAmount(String raw) {
    final String compact = raw.trim().replaceAll(' ', '');
    if (compact.isEmpty) {
      throw const FormatException('Amount is missing');
    }
    final String normalized = compact.replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
      throw FormatException('Invalid amount: $raw');
    }
    final double value = double.parse(normalized);
    if (value <= 0) {
      throw FormatException('Amount must be positive: $raw');
    }
    if (value > maxAmount) {
      throw FormatException('Amount exceeds the maximum of $maxAmount: $raw');
    }
    return _round2(value);
  }

  double _decodeObfuscatedAmount(String obfuscated) {
    if (obfuscated.length != 8) {
      throw const FormatException('Malformed obfuscated amount');
    }
    int bani = 0;
    for (int i = 0; i < obfuscated.length; i++) {
      final int digit = obfuscated.codeUnitAt(i) - 48;
      if (digit < 0 || digit > 9) {
        throw const FormatException('Malformed obfuscated amount');
      }
      bani = bani * 10 + ((digit - i) % 10);
    }
    final double value = _round2(bani / 100);
    if (value <= 0) {
      throw const FormatException('Amount must be positive');
    }
    if (value > maxAmount) {
      throw FormatException('Amount exceeds the maximum of $maxAmount');
    }
    return value;
  }

  DateTime _parseDate(String raw) {
    final String value = raw.trim();
    final RegExpMatch? dotted =
        RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (dotted != null) {
      return _makeDate(
        int.parse(dotted.group(3)!),
        int.parse(dotted.group(2)!),
        int.parse(dotted.group(1)!),
      );
    }
    final RegExpMatch? iso =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (iso != null) {
      return _makeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final RegExpMatch? compact = RegExp(r'^(\d{2})(\d{2})(\d{2})$').firstMatch(value);
    if (compact != null) {
      return _makeDate(
        2000 + int.parse(compact.group(3)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(1)!),
      );
    }
    throw FormatException('Unsupported due date format: $raw');
  }

  DateTime _makeDate(int year, int month, int day) {
    final DateTime date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException(
        'Invalid due date: $year-$month-$day',
      );
    }
    return date;
  }

  void _validateDueDate(DateTime dueDate) {
    if (dueDate.isBefore(_minDueDate)) {
      throw FormatException(
        'Due date is too far in the past: ${dueDate.toIso8601String()}',
      );
    }
    final DateTime limit =
        now().toUtc().add(const Duration(days: maxDueDateFutureDays));
    if (dueDate.isAfter(limit)) {
      throw FormatException(
        'Due date is too far in the future: ${dueDate.toIso8601String()}',
      );
    }
  }

  String _stripLeadingZeros(String value) {
    final String stripped = value.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }

  int _mod97(String iban) {
    final String rearranged = iban.substring(4) + iban.substring(0, 4);
    int remainder = 0;
    for (int i = 0; i < rearranged.length; i++) {
      final int codeUnit = rearranged.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        remainder = (remainder * 10 + (codeUnit - 48)) % 97;
      } else {
        remainder = (remainder * 100 + (codeUnit - 55)) % 97;
      }
    }
    return remainder;
  }
}
