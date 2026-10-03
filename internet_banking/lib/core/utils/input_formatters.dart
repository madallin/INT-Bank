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

class AmountInputFormatter extends TextInputFormatter
{
  final int decimalPlaces;

  AmountInputFormatter({this.decimalPlaces = 2});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final cleaned = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if(cleaned.isEmpty) return TextEditingValue.empty;

    final integerPart = cleaned.substring(0, cleaned.length - decimalPlaces);
    final decimalPart = cleaned.substring(cleaned.length - decimalPlaces);

    final formattedInteger = _formatWithThousandsSeparator(integerPart);
    final formatted = '$formattedInteger.$decimalPart';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithThousandsSeparator(String value)
  {
    if(value.isEmpty) return '0';
    final buffer = StringBuffer();
    for(int i = 0; i < value.length; i++)
{
      if(i > 0 && (value.length - i) % 3 == 0) buffer.write('.');
      buffer.write(value[i]);
    }
    return buffer.toString();
  }
}

/// Formats a money amount the Romanian way while typing: `1.234,56`.
///
/// `,` is the decimal separator and `.` groups thousands. Because many numeric
/// keyboards only offer `.`, an inserted `.` that cannot be a thousands group
/// (it is followed by at most [decimalPlaces] digits) is read as the decimal
/// separator, so typing `12.5` or pasting `12.50` both yield `12,50`.
class RomanianAmountInputFormatter extends TextInputFormatter
{
  final int decimalPlaces;
  final int maxIntegerDigits;

  RomanianAmountInputFormatter({this.decimalPlaces = 2, this.maxIntegerDigits = 9});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    var text = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');
    final isInsertion = newValue.text.length > oldValue.text.length;

    if(isInsertion && !text.contains(','))
    {
      final lastDot = text.lastIndexOf('.');
      if(lastDot != -1 && text.length - lastDot - 1 <= decimalPlaces)
      {
        text = '${text.substring(0, lastDot)},${text.substring(lastDot + 1)}';
      }
    }

    final commaIndex = text.indexOf(',');
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
      if(i > 0 && (integerDigits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(integerDigits[i]);
    }
    final formatted = hasDecimal ? '$grouped,$decimalDigits' : grouped.toString();

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
