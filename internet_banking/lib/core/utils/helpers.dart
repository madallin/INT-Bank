import 'package:flutter/material.dart';

void showErrorSnackBar(BuildContext context, String message)
{
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: Colors.red,
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message)
{
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: Colors.green,
    ),
  );
}

String formatPhoneDisplay(String phone)
{
  if(phone.length >= 12)
{
    final countryCode = phone.substring(0, 3);
    final rest = phone.substring(3);
    final formattedRest = '${rest.substring(0, 3)} ${rest.substring(3, 6)} ${rest.substring(6)}';
    return '$countryCode $formattedRest';
  }
  return phone;
}

String countryCodeToEmoji(String countryCode)
{
  final codePoint1 = 0x1F1E6 + countryCode.codeUnitAt(0) - 65;
  final codePoint2 = 0x1F1E6 + countryCode.codeUnitAt(1) - 65;
  return String.fromCharCodes([codePoint1, codePoint2]);
}

String formatDate(String dateStr)
{
  try
  {
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
  catch(e)
{
    return dateStr;
  }
}

double? parseRomanianNumber(String text)
{
  try
  {
    return double.parse(text.replaceAll('.', '').replaceAll(',', '.'));
  }
  catch(e)
{
    return null;
  }
}

String toTitleCase(String text)
{
  if(text.isEmpty) return text;
  return text.split(' ').map((word)
  {
    if(word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

ImageProvider cachedNetworkImage(String url)
{
  return NetworkImage(url);
}

String formatIBAN(String iban)
{
  final cleaned = iban.replaceAll(' ', '');
  final buffer = StringBuffer();
  for(int i = 0; i < cleaned.length; i++)
{
    if(i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(cleaned[i]);
  }
  return buffer.toString();
}

T enumFromString<T>(String key, List<T> values)
{
  return values.firstWhere((v) => v.toString().split('.').last == key);
}
