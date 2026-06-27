import 'package:flutter/services.dart';

class IBANInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue)
  {
    final cleaned = newValue.text.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for(int i = 0; i < cleaned.length; i++)
{
      if(i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    final formatted = buffer.toString();
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
