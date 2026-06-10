// lib/core/utils/input_formatters.dart
// Custom TextInputFormatters for real-time input validation and formatting

import 'package:flutter/services.dart';

/// A [TextInputFormatter] for the "Nume de familie" (last name) field.
///
/// Rules:
/// - Only letters (including Romanian diacritics ăâîșțĂÂÎȘȚ) and hyphens allowed.
/// - No spaces allowed.
/// - Maximum 2 words, separated by a single hyphen (e.g., "Popescu" or "Popescu-Ionescu").
/// - No consecutive hyphens.
/// - Auto-capitalizes the first letter and the letter after a hyphen.
class LastNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Step 1: Filter out disallowed characters (only letters, hyphens)
    String filtered = newValue.text.replaceAll(
      RegExp(r'[^a-zA-ZăâîșțĂÂÎȘȚ\-]'),
      '',
    );

    // Step 2: Remove consecutive hyphens (e.g., "a--b" → "a-b")
    filtered = filtered.replaceAll(RegExp(r'-{2,}'), '-');

    // Step 3: Remove leading hyphen
    if (filtered.startsWith('-')) {
      filtered = filtered.substring(1);
    }

    // Step 4: If there's already a hyphen, don't allow a second one
    final hyphenIndex = filtered.indexOf('-');
    if (hyphenIndex >= 0) {
      // Remove any extra hyphens after the first one
      final beforeHyphen = filtered.substring(0, hyphenIndex);
      final afterHyphen = filtered
          .substring(hyphenIndex + 1)
          .replaceAll('-', '');
      filtered = '$beforeHyphen-$afterHyphen';
    }

    if (filtered.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Step 6: Capitalize words
    filtered = _capitalizeName(filtered);

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }

  /// Capitalizes the first letter of each word (separated by hyphen).
  String _capitalizeName(String input) {
    final parts = input.split('-');
    final capitalizedParts = parts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).toList();
    return capitalizedParts.join('-');
  }
}

/// A [TextInputFormatter] that allows only a single letter (A-Z, including Romanian diacritics).
/// Used for the "Scară" field (e.g., Sc. A, Sc. B).
class SingleLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Only allow a single letter
    String filtered = newValue.text.replaceAll(
      RegExp(r'[^a-zA-ZăâîșțĂÂÎȘȚ]'),
      '',
    );

    // Allow only the first character, capitalize it
    if (filtered.length > 1) {
      filtered = filtered.substring(0, 1);
    }

    filtered = filtered.toUpperCase();

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

/// A [TextInputFormatter] for the "Prenume" (first name) field.
///
/// Rules:
/// - Only letters (including Romanian diacritics ăâîșțĂÂÎȘȚ), spaces, and hyphens allowed.
/// - No double spaces (cannot type two spaces in a row).
/// - No spaces around hyphens: typing "Andrei - Marian" becomes "Andrei-Marian".
/// - Auto-capitalizes the first letter and the letter after a space or hyphen.
class FirstNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Step 1: Filter out disallowed characters
    String filtered = newValue.text.replaceAll(
      RegExp(r'[^a-zA-ZăâîșțĂÂÎȘȚ\s\-]'),
      '',
    );

    if (filtered.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Step 2: Remove spaces around hyphens and clean up
    // "A - B" → "A-B", "A- B" → "A-B", "A -B" → "A-B"
    filtered = filtered.replaceAll(RegExp(r'\s*-\s*'), '-');

    // Step 3: Remove double spaces
    filtered = filtered.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Step 4: Remove leading space
    if (filtered.startsWith(' ')) {
      filtered = filtered.substring(1);
    }

    // Step 5: Remove consecutive hyphens
    filtered = filtered.replaceAll(RegExp(r'-{2,}'), '-');

    if (filtered.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Step 6: Build the capitalized string
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < filtered.length; i++) {
      final ch = filtered[i];

      if (ch == ' ' || ch == '-') {
        buffer.write(ch);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(ch.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(ch.toLowerCase());
      }
    }

    final result = buffer.toString();

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
