import 'package:flutter/material.dart';

class RomanianBankInfo {
  final String code;
  final String name;
  final Color primaryColor;

  const RomanianBankInfo({
    required this.code,
    required this.name,
    required this.primaryColor,
  });
}

class IbanBankDetector {
  static const Map<String, RomanianBankInfo> _knownBanks = {
    'BTRL': RomanianBankInfo(code: 'BTRL', name: 'Banca Transilvania', primaryColor: Color(0xFF1B365D)),
    'RNCB': RomanianBankInfo(code: 'RNCB', name: 'Banca Comerciala Româna (BCR)', primaryColor: Color(0xFF004F9F)),
    'INGB': RomanianBankInfo(code: 'INGB', name: 'ING Bank România', primaryColor: Color(0xFFFF6200)),
    'BRDE': RomanianBankInfo(code: 'BRDE', name: 'BRD Groupe Société Générale', primaryColor: Color(0xFFE20613)),
    'RZBR': RomanianBankInfo(code: 'RZBR', name: 'Raiffeisen Bank', primaryColor: Color(0xFF231F20)),
    'CECE': RomanianBankInfo(code: 'CECE', name: 'CEC Bank', primaryColor: Color(0xFF006837)),
    'BREL': RomanianBankInfo(code: 'BREL', name: 'Libra Internet Bank', primaryColor: Color(0xFF7B1113)),
    'INTB': RomanianBankInfo(code: 'INTB', name: 'INTBank România', primaryColor: Color(0xFF00695C)),
    'UGBI': RomanianBankInfo(code: 'UGBI', name: 'Garanti BBVA', primaryColor: Color(0xFF005A36)),
    'TREZ': RomanianBankInfo(code: 'TREZ', name: 'Trezoreria Statului', primaryColor: Color(0xFF4A5568)),
  };

  static RomanianBankInfo? detectBank(String iban) {
    final clean = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.length >= 8 && clean.startsWith('RO')) {
      final code = clean.substring(4, 8);
      return _knownBanks[code] ?? RomanianBankInfo(code: code, name: 'Banca din România ()', primaryColor: Colors.grey.shade700);
    }
    return null;
  }
}
