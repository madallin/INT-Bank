import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'formatters.dart';

enum SnackBarTone { error, success, info }

/// The one way screens show transient feedback, so colour, icon, placement and
/// timing stay consistent. A new message replaces the visible one instead of
/// queueing behind it.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarTone tone = SnackBarTone.info,
  Duration duration = const Duration(seconds: 4),
})
{
  final colors = context.colors;
  final (Color background, IconData icon) = switch (tone)
  {
    SnackBarTone.error => (colors.danger, Icons.error_outline_rounded),
    SnackBarTone.success => (colors.brand, Icons.check_circle_outline_rounded),
    SnackBarTone.info => (colors.textPrimary, Icons.info_outline_rounded),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
}

void showErrorSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message, tone: SnackBarTone.error);

void showSuccessSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message, tone: SnackBarTone.success);

void showInfoSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message);

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

/// Reads an amount typed or shown in the active language (`1.234,56` or `1,234.56`).
double? parseAmount(String text)
{
  final sep = numberSeparators;
  try
  {
    return double.parse(text.replaceAll(sep.group, '').replaceAll(sep.decimal, '.'));
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

T enumFromString<T>(String key, List<T> values)
{
  return values.firstWhere((v) => v.toString().split('.').last == key);
}
