import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';

import '../theme/app_tokens.dart';
import 'country_dropdown.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;
  final ValueChanged<CountryWithPhoneCode?> onCountryChanged;
  final String Function(String) formatAsYouType;
  final String hintText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.countries,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.formatAsYouType,
    required this.hintText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CountryDropdown(
          countries: countries,
          selectedCountry: selectedCountry,
          onChanged: onCountryChanged,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final formatted = formatAsYouType(newValue.text);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
              LengthLimitingTextInputFormatter(15),
            ],
            style: context.text.bodyLarge,
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
      ],
    );
  }
}
