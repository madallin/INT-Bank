import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';

import '../core/utils/helpers.dart';
import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

/// Flag + dialling-code picker shown next to phone number inputs.
class CountryDropdown extends StatelessWidget {
  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;
  final ValueChanged<CountryWithPhoneCode?> onChanged;

  const CountryDropdown({
    super.key,
    required this.countries,
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decoration = BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: c.border, width: 1.5),
    );
    if (countries.isEmpty) {
      return Container(
        width: 110,
        height: 58,
        alignment: Alignment.center,
        decoration: decoration,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Semantics(
      label: context.l10n.commonPrefixTara,
      child: Container(
        width: 110,
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: decoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<CountryWithPhoneCode>(
            value: selectedCountry,
            isExpanded: true,
            dropdownColor: c.surface,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: c.textMuted, size: 14),
            style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            items: countries.map((country) {
              return DropdownMenuItem<CountryWithPhoneCode>(
                value: country,
                child: Row(
                  children: [
                    Text(countryCodeToEmoji(country.countryCode),
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    // Long codes (+373, +1 684) and large text shrink instead of overflowing.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('+${country.phoneCode}', style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
