import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Supported QR payment standards.
enum QrStandardType { epcSepa, roPayInstant, unknown }

/// Immutable, validated QR payment payload shared across supported standards.
@immutable
class QrPaymentPayload {
  final String beneficiaryName;
  final String iban;
  final String? bic;
  final double amount;
  final String currency;
  final String? remittanceReference;
  final String? purposeCode;

  const QrPaymentPayload({
    required this.beneficiaryName,
    required this.iban,
    this.bic,
    required this.amount,
    required this.currency,
    this.remittanceReference,
    this.purposeCode,
  });

  QrPaymentPayload copyWith({
    String? beneficiaryName,
    String? iban,
    String? bic,
    double? amount,
    String? currency,
    String? remittanceReference,
    String? purposeCode,
  }) {
    return QrPaymentPayload(
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      remittanceReference: remittanceReference ?? this.remittanceReference,
      purposeCode: purposeCode ?? this.purposeCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QrPaymentPayload &&
        other.beneficiaryName == beneficiaryName &&
        other.iban == iban &&
        other.bic == bic &&
        other.amount == amount &&
        other.currency == currency &&
        other.remittanceReference == remittanceReference &&
        other.purposeCode == purposeCode;
  }

  @override
  int get hashCode => Object.hash(
        beneficiaryName,
        iban,
        bic,
        amount,
        currency,
        remittanceReference,
        purposeCode,
      );

  @override
  String toString() {
    return 'QrPaymentPayload(beneficiaryName: $beneficiaryName, iban: $iban, '
        'bic: $bic, amount: $amount, currency: $currency, '
        'remittanceReference: $remittanceReference, purposeCode: $purposeCode)';
  }
}

/// Generates and parses European standard QR payment payloads.
///
/// Two standards are supported:
///  - EPC069-12 / BCD (SEPA Credit Transfer QR).
///  - RoPay instant (TRANSFOND), a deterministic pipe delimited record.
class QrPaymentService {
  /// EPC069-12 maximum length for the beneficiary name.
  static const int epcMaxBeneficiaryNameLength = 70;

  /// EPC069-12 maximum length for the remittance reference.
  static const int epcMaxRemittanceLength = 140;

  static const String _epcServiceTag = 'BCD';
  static const String _epcVersion = '002';
  static const String _epcCharacterSet = '1';
  static const String _epcIdentification = 'SCT';
  static const String _roPayServiceTag = 'ROPAY1';
  static const String _roPayDelimiter = '|';

  /// Generates an EPC069-12 (BCD) SEPA Credit Transfer payload.
  ///
  /// The output contains exactly ten lines joined by a single line feed:
  /// 1. `BCD`
  /// 2. `002` (version)
  /// 3. `1` (UTF-8 character set)
  /// 4. `SCT` (SEPA Credit Transfer)
  /// 5. BIC (possibly empty)
  /// 6. Beneficiary name
  /// 7. IBAN
  /// 8. Amount, for example `EUR12.50`
  /// 9. Purpose code (possibly empty)
  /// 10. Remittance reference (possibly empty)
  ///
  /// Throws [ArgumentError] when the beneficiary name exceeds 70 characters,
  /// when the remittance reference exceeds 140 characters, when the amount is
  /// not positive, or when the IBAN fails the ISO 13616 mod-97 check.
  String generateEpcPayload(QrPaymentPayload payload) {
    final String name = payload.beneficiaryName;
    if (name.length > epcMaxBeneficiaryNameLength) {
      throw ArgumentError.value(
        name,
        'beneficiaryName',
        'must not exceed $epcMaxBeneficiaryNameLength characters',
      );
    }
    final String reference = payload.remittanceReference ?? '';
    if (reference.length > epcMaxRemittanceLength) {
      throw ArgumentError.value(
        reference,
        'remittanceReference',
        'must not exceed $epcMaxRemittanceLength characters',
      );
    }
    _validateAmount(payload.amount);
    final String normalizedIban = _normalizeIban(payload.iban);
    if (!isValidIban(normalizedIban)) {
      throw ArgumentError.value(payload.iban, 'iban', 'invalid IBAN');
    }

    final List<String> lines = <String>[
      _epcServiceTag,
      _epcVersion,
      _epcCharacterSet,
      _epcIdentification,
      payload.bic ?? '',
      name,
      normalizedIban,
      _formatEpcAmount(payload.amount, payload.currency),
      payload.purposeCode ?? '',
      reference,
    ];
    return lines.join('\n');
  }

  /// Generates a deterministic RoPay instant payment payload.
  ///
  /// The format is a single pipe delimited line:
  ///
  /// `ROPAY1|aliasOrIban|name|amount|currency|ref|CRC16`
  ///
  /// - `ROPAY1` is the fixed service tag and format version.
  /// - `aliasOrIban` is the normalized IBAN of the beneficiary.
  /// - `name` is the beneficiary name.
  /// - `amount` is the decimal amount with exactly two fraction digits.
  /// - `currency` is the upper case ISO 4217 code.
  /// - `ref` is the remittance reference, empty when absent.
  /// - `CRC16` is four upper case hexadecimal digits computed with
  ///   CRC-16/CCITT-FALSE (polynomial 0x1021, initial value 0xFFFF, no
  ///   reflection, final xor 0x0000) over the UTF-8 bytes of the six fields
  ///   that precede the checksum, joined with `|`.
  ///
  /// Throws [ArgumentError] for invalid field content.
  String generateRoPayPayload(QrPaymentPayload payload) {
    final String name = payload.beneficiaryName;
    if (name.length > epcMaxBeneficiaryNameLength) {
      throw ArgumentError.value(
        name,
        'beneficiaryName',
        'must not exceed $epcMaxBeneficiaryNameLength characters',
      );
    }
    final String reference = payload.remittanceReference ?? '';
    if (reference.length > epcMaxRemittanceLength) {
      throw ArgumentError.value(
        reference,
        'remittanceReference',
        'must not exceed $epcMaxRemittanceLength characters',
      );
    }
    if (name.contains(_roPayDelimiter)) {
      throw ArgumentError.value(
        name,
        'beneficiaryName',
        'must not contain the pipe delimiter',
      );
    }
    if (reference.contains(_roPayDelimiter)) {
      throw ArgumentError.value(
        reference,
        'remittanceReference',
        'must not contain the pipe delimiter',
      );
    }
    _validateAmount(payload.amount);
    final String normalizedIban = _normalizeIban(payload.iban);
    if (!isValidIban(normalizedIban)) {
      throw ArgumentError.value(payload.iban, 'iban', 'invalid IBAN');
    }

    final String prefix = <String>[
      _roPayServiceTag,
      normalizedIban,
      name,
      payload.amount.toStringAsFixed(2),
      payload.currency.toUpperCase(),
      reference,
    ].join(_roPayDelimiter);
    return '$prefix$_roPayDelimiter${computeCrc16(prefix)}';
  }

  /// Detects the standard encoded in [rawContent].
  QrStandardType detectStandard(String rawContent) {
    final String trimmed = rawContent.trim();
    if (trimmed.startsWith(_epcServiceTag)) {
      return QrStandardType.epcSepa;
    }
    if (trimmed.startsWith('ROPAY')) {
      return QrStandardType.roPayInstant;
    }
    return QrStandardType.unknown;
  }

  /// Parses [rawContent] into a [QrPaymentPayload].
  ///
  /// Throws [FormatException] when the content is empty, uses an unknown
  /// standard, is structurally malformed, has an invalid IBAN, has a
  /// non-positive amount or more than two fraction digits, or, for RoPay, has
  /// a mismatching CRC16 checksum.
  QrPaymentPayload parsePayload(String rawContent) {
    final QrStandardType standard = detectStandard(rawContent);
    if (standard == QrStandardType.epcSepa) {
      return _parseEpc(rawContent.trim());
    }
    if (standard == QrStandardType.roPayInstant) {
      return _parseRoPay(rawContent.trim());
    }
    throw const FormatException('Unknown QR payment standard');
  }

  /// Returns true only when parsing and validation succeed; never throws.
  bool validatePayload(String rawContent) {
    try {
      parsePayload(rawContent);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validates an IBAN using the ISO 13616 mod-97 checksum.
  bool isValidIban(String iban) {
    final String cleaned = _normalizeIban(iban);
    if (cleaned.length < 15 || cleaned.length > 34) {
      return false;
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(cleaned)) {
      return false;
    }
    final String rearranged = cleaned.substring(4) + cleaned.substring(0, 4);
    int remainder = 0;
    for (int i = 0; i < rearranged.length; i++) {
      final int codeUnit = rearranged.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        remainder = (remainder * 10 + (codeUnit - 48)) % 97;
      } else if (codeUnit >= 65 && codeUnit <= 90) {
        remainder = (remainder * 100 + (codeUnit - 55)) % 97;
      } else {
        return false;
      }
    }
    return remainder == 1;
  }

  /// Computes CRC-16/CCITT-FALSE over the UTF-8 bytes of [input].
  ///
  /// Uses polynomial 0x1021, initial value 0xFFFF, no input or output
  /// reflection and a final xor of 0x0000. The result is returned as four
  /// upper case hexadecimal digits.
  String computeCrc16(String input) {
    final List<int> bytes = utf8.encode(input);
    int crc = 0xFFFF;
    for (final int byte in bytes) {
      crc = (crc ^ (byte << 8)) & 0xFFFF;
      for (int bit = 0; bit < 8; bit++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Parses an amount string, tolerating both `EUR12.50` and `12.50` forms.
  ///
  /// Returns null when the value is empty, is not a positive number with at
  /// most two fraction digits, or fails to parse.
  double? parseAmount(String rawAmount, String currency) {
    final String trimmed = rawAmount.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    String numeric = trimmed;
    final String upperCurrency = currency.trim().toUpperCase();
    if (upperCurrency.length == 3 &&
        trimmed.toUpperCase().startsWith(upperCurrency)) {
      numeric = trimmed.substring(3).trim();
    } else {
      final RegExpMatch? codeMatch =
          RegExp(r'^([A-Za-z]{3})\s*(.+)$').firstMatch(trimmed);
      if (codeMatch != null) {
        numeric = codeMatch.group(2)!.trim();
      }
    }
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(numeric)) {
      return null;
    }
    final double? value = double.tryParse(numeric);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  QrPaymentPayload _parseEpc(String content) {
    final List<String> lines = content.split('\n');
    if (lines.length < 8) {
      throw const FormatException('EPC payload is truncated');
    }
    if (lines[0].trim() != _epcServiceTag ||
        lines[1].trim() != _epcVersion ||
        lines[2].trim() != _epcCharacterSet ||
        lines[3].trim() != _epcIdentification) {
      throw const FormatException('EPC header is invalid');
    }
    final String bic = lines[4].trim();
    final String name = lines[5].trim();
    final String iban = lines[6].trim();
    final String amountLine = lines[7].trim();
    final String purpose = lines.length > 8 ? lines[8].trim() : '';
    final String reference = lines.length > 9 ? lines[9].trim() : '';

    if (!isValidIban(iban)) {
      throw FormatException('Invalid IBAN: $iban');
    }
    final String currency = _extractCurrency(amountLine) ?? 'EUR';
    final double? amount = parseAmount(amountLine, currency);
    if (amount == null) {
      throw FormatException('Invalid amount: $amountLine');
    }
    return QrPaymentPayload(
      beneficiaryName: name,
      iban: _normalizeIban(iban),
      bic: bic.isEmpty ? null : bic,
      amount: amount,
      currency: currency,
      remittanceReference: reference.isEmpty ? null : reference,
      purposeCode: purpose.isEmpty ? null : purpose,
    );
  }

  QrPaymentPayload _parseRoPay(String content) {
    final List<String> parts = content.split(_roPayDelimiter);
    if (parts.length != 7) {
      throw const FormatException('RoPay payload must contain exactly 7 fields');
    }
    if (parts[0] != _roPayServiceTag) {
      throw const FormatException('RoPay service tag is invalid');
    }
    final String iban = parts[1].trim();
    final String name = parts[2];
    final String amountRaw = parts[3].trim();
    final String currency = parts[4].trim().toUpperCase();
    final String reference = parts[5];
    final String checksum = parts[6].trim().toUpperCase();

    final String prefix = parts.sublist(0, 6).join(_roPayDelimiter);
    if (computeCrc16(prefix) != checksum) {
      throw const FormatException('RoPay CRC16 checksum mismatch');
    }
    if (!isValidIban(iban)) {
      throw FormatException('Invalid IBAN: $iban');
    }
    final double? amount = parseAmount(amountRaw, currency);
    if (amount == null) {
      throw FormatException('Invalid amount: $amountRaw');
    }
    return QrPaymentPayload(
      beneficiaryName: name,
      iban: _normalizeIban(iban),
      amount: amount,
      currency: currency,
      remittanceReference: reference.isEmpty ? null : reference,
    );
  }

  void _validateAmount(double amount) {
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      throw ArgumentError.value(amount, 'amount', 'amount must be positive');
    }
  }

  String _formatEpcAmount(double amount, String currency) {
    return '${currency.toUpperCase()}${amount.toStringAsFixed(2)}';
  }

  String? _extractCurrency(String amountLine) {
    final RegExpMatch? match =
        RegExp(r'^([A-Za-z]{3})').firstMatch(amountLine.trim());
    return match?.group(1)?.toUpperCase();
  }

  String _normalizeIban(String iban) {
    return iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }
}
