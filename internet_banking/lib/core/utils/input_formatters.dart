import 'package:flutter/services.dart';

import 'formatters.dart';

class IBANInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final formatted = formatIban(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats a money amount while typing, with the active language's separators
/// (Romanian `1.234,56`, English `1,234.56`; see [numberSeparators]).
///
/// Many numeric keyboards offer only one separator key, so an inserted grouping
/// separator that cannot be a thousands group (it is followed by at most
/// [decimalPlaces] digits) is read as the decimal point: in Romanian, typing `12.5`
/// or pasting `12.50` both yield `12,50`.
class AmountInputFormatter extends TextInputFormatter
{
  final int decimalPlaces;
  final int maxIntegerDigits;

  AmountInputFormatter({this.decimalPlaces = 2, this.maxIntegerDigits = 9});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final sep = numberSeparators;
    var text = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');
    final isInsertion = newValue.text.length > oldValue.text.length;

    // The keyboard may offer the other separator: when the last one has no more digits
    // after it than a decimal part can, it is the decimal point.
    if(isInsertion && !text.contains(sep.decimal))
    {
      final lastGroup = text.lastIndexOf(sep.group);
      if(lastGroup != -1 && text.length - lastGroup - 1 <= decimalPlaces)
      {
        text = '${text.substring(0, lastGroup)}${sep.decimal}${text.substring(lastGroup + 1)}';
      }
    }

    final commaIndex = text.indexOf(sep.decimal);
    final hasDecimal = commaIndex != -1 && decimalPlaces > 0;
    var integerDigits = (hasDecimal ? text.substring(0, commaIndex) : text)
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var decimalDigits = hasDecimal
        ? text.substring(commaIndex + 1).replaceAll(RegExp(r'\D'), '')
        : '';

    if(integerDigits.length > maxIntegerDigits) return oldValue;
    if(decimalDigits.length > decimalPlaces)
    {
      decimalDigits = decimalDigits.substring(0, decimalPlaces);
    }
    if(integerDigits.isEmpty && hasDecimal) integerDigits = '0';
    if(integerDigits.isEmpty) return TextEditingValue.empty;

    final grouped = StringBuffer();
    for(int i = 0; i < integerDigits.length; i++)
    {
      if(i > 0 && (integerDigits.length - i) % 3 == 0) grouped.write(sep.group);
      grouped.write(integerDigits[i]);
    }
    final formatted = hasDecimal ? '$grouped${sep.decimal}$decimalDigits' : grouped.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for(int i = 0; i < digits.length; i++)
{
      if(i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class UpperCaseInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class CNPInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for(int i = 0; i < digits.length && i < 13; i++)
{
      if(i == 1 || i == 3 || i == 5 || i == 7 || i == 9 || i == 11)
{
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
